#!/bin/bash
# Journal Scout — CE/PM Daily Pipeline
# 每天自动扫描建工/PM期刊最近5天新论文
# 由 Codex Automation 触发，通过独立 Python 脚本执行扫描

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PIPELINE_DIR="$REPO_DIR/pipeline"
LOCAL_CONFIG="$REPO_DIR/config/local.sh"
[ -f "$LOCAL_CONFIG" ] && source "$LOCAL_CONFIG"

# ── 文件锁（防止睡眠唤醒后多脚本同时写 data/） ──
LOCKDIR="/tmp/idea_scout_pipeline.lock"
LOCK_WAIT=0
while ! mkdir "$LOCKDIR" 2>/dev/null; do
    # 防腐：锁超过 10 分钟视为残留，强制清除
    if [ -d "$LOCKDIR" ] && [ "$(( $(date +%s) - $(stat -f %m "$LOCKDIR") ))" -gt 600 ]; then
        echo "WARN: stale lock detected (>10min), force removing" >> "${LOG_DIR:-/tmp}/idea-scout-lock.log"
        rmdir "$LOCKDIR" 2>/dev/null || rm -rf "$LOCKDIR"
        continue
    fi
    sleep 10
    LOCK_WAIT=$((LOCK_WAIT + 10))
    if [ $LOCK_WAIT -ge 300 ]; then
        echo "ERROR: lock wait timeout (5min), aborting" >> "${LOG_DIR:-/tmp}/idea-scout-lock.log"
        exit 1
    fi
done
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

LOG_DIR="${LOG_DIR:-$REPO_DIR/logs}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/cepm-$(date +%Y%m%d-%H%M%S).log"
TODAY=$(date +%Y-%m-%d)
SCAN_FROM=$(date -v-5d +%Y-%m-%d)
DASHBOARD_URL="${DASHBOARD_URL:-http://127.0.0.1:5174}"

# 设置 PATH（定时任务环境不继承 shell 的 PATH）
export PATH="$HOME/anaconda3/bin:$HOME/.local/bin:$HOME/develop/flutter/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# 加载本地配置（可选：用于 CHATANYWHERE_API_KEY / EMAIL_TO）
if [ -n "${EMAIL_CONFIG_PATH:-}" ]; then
    if [ ! -f "$EMAIL_CONFIG_PATH" ]; then
        echo "ERROR: EMAIL_CONFIG_PATH does not exist: $EMAIL_CONFIG_PATH" >> "$LOG_FILE"
        exit 1
    fi
    source "$EMAIL_CONFIG_PATH"
fi
export CHATANYWHERE_API_KEY
if [ -n "${IDEA_SCOUT_EMAIL_TO:-}" ]; then
    EMAIL_TO="$IDEA_SCOUT_EMAIL_TO"
    CEPM_EMAIL_TO="$IDEA_SCOUT_EMAIL_TO"
fi
export EMAIL_TO CEPM_EMAIL_TO

echo "=== CE/PM Daily Scan ===" >> "$LOG_FILE"
echo "Started: $(date), range: $SCAN_FROM ~ $TODAY" >> "$LOG_FILE"

# cd 到 repo 根目录（pipeline 和 data/ 在同一 repo）
cd "$REPO_DIR" || exit 1

# ── 本地正本：Dashboard 直接写 data/user_state.json ──
rm -f /tmp/idea_scout_user_state.json
cp data/user_state.json /tmp/idea_scout_user_state.json 2>/dev/null || true

# ── 扫描（独立 Python 脚本，失败过半则重试一次） ──
run_cepm_scan() {
    set -o pipefail
    python3 "$PIPELINE_DIR/scanners/openalex_scanner.py" \
        --config "$REPO_DIR/config/cepm-journals.json" \
        --from "$SCAN_FROM" --to "$TODAY" \
        --output "data/cepm_latest.json" \
        2>&1 | tee -a "$LOG_FILE"
}

SCAN_OUTPUT=$(run_cepm_scan)
EXIT_CODE=${PIPESTATUS[0]:-$?}
echo "Scan finished: $(date), exit code: $EXIT_CODE" >> "$LOG_FILE"

# 检查成功期刊数，不足 3 本则等 30 秒重试一次（共 12 本）
JOURNAL_COUNT=$(echo "$SCAN_OUTPUT" | sed -n 's/.*from \([0-9]*\) journals.*/\1/p' | tail -1)
JOURNAL_COUNT=${JOURNAL_COUNT:-0}
if [ "$JOURNAL_COUNT" -lt 3 ]; then
    echo "RETRY: only $JOURNAL_COUNT journals succeeded (<3), retrying in 30s..." >> "$LOG_FILE"
    sleep 30
    SCAN_OUTPUT=$(run_cepm_scan)
    EXIT_CODE=${PIPESTATUS[0]:-$?}
    echo "Retry scan finished: $(date), exit code: $EXIT_CODE" >> "$LOG_FILE"

    RETRY_COUNT=$(echo "$SCAN_OUTPUT" | sed -n 's/.*from \([0-9]*\) journals.*/\1/p' | tail -1)
    RETRY_COUNT=${RETRY_COUNT:-0}
    if [ "$RETRY_COUNT" -lt 3 ]; then
        echo "WARN: retry still only $RETRY_COUNT journals; Codex Automation should send any Gmail alert" >> "$LOG_FILE"
    fi
fi

if [ $EXIT_CODE -ne 0 ] || [ ! -s "data/cepm_latest.json" ]; then
    echo "Scan failed, aborting" >> "$LOG_FILE"
    osascript -e 'display notification "CE/PM scan failed, check logs" with title "CE/PM Scout" subtitle "Failed" sound name "Basso"'
    exit 1
fi

# ── 合并数据 ──
python3 - "data/cepm_latest.json" "data/cepm_papers.json" "$TODAY" << 'PYEOF'
import json, sys

latest_path, papers_path, scan_date = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(latest_path, 'r') as f:
        new_papers = json.load(f)
    if isinstance(new_papers, dict) and 'papers' in new_papers:
        new_papers = new_papers['papers']
except Exception as e:
    print(f"Cannot read cepm_latest.json: {e}", file=sys.stderr)
    sys.exit(0)

for p in new_papers:
    p['scan_date'] = scan_date

try:
    with open(papers_path, 'r') as f:
        all_papers = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    all_papers = []

doi_map = {p.get('doi', ''): p for p in all_papers if p.get('doi')}
for p in new_papers:
    if p.get('doi'):
        doi_map[p['doi']] = p

# 加载 user_state.json，过滤已删除/已加入 Idea 的论文
deleted_dois = set()
try:
    with open('/tmp/idea_scout_user_state.json', 'r') as f:
        _us = json.load(f)
    _raw = _us.get('cepm', {}).get('deleted_dois', [])
    deleted_dois = set((x['id'] if isinstance(x, dict) else x) for x in _raw)
    for ip in _us.get('cepm', {}).get('idea_papers', []):
        tid = ip.get('tracking_id', ip.get('doi', ''))
        if tid: deleted_dois.add(tid)
except (FileNotFoundError, json.JSONDecodeError):
    pass

all_papers = [p for doi, p in doi_map.items() if doi not in deleted_dois]

from datetime import datetime, timedelta
cutoff = (datetime.now() - timedelta(days=30)).strftime('%Y-%m-%d')
all_papers = [p for p in all_papers if p.get('scan_date', p.get('date', '9999')) >= cutoff]
all_papers.sort(key=lambda p: p.get('date', ''), reverse=True)

with open(papers_path, 'w') as f:
    json.dump(all_papers, f, ensure_ascii=False)

print(f"Merged: {len(new_papers)} fetched, {len(all_papers)} total")
PYEOF

echo "Merge done" >> "$LOG_FILE"

# ── 统计去重后真实新论文数 ──
NEW_COUNT=$(python3 -c "
import json
papers = json.load(open('data/cepm_latest.json'))
if isinstance(papers, dict) and 'papers' in papers: papers = papers['papers']
try: seen = set(json.load(open('data/cepm_seen_dois.json')))
except: seen = set()
new = [p for p in papers if not p.get('doi') or p['doi'] not in seen]
print(len(new))
" 2>/dev/null || echo "0")
echo "New papers (after dedup): $NEW_COUNT" >> "$LOG_FILE"

# ── 日报导出（由 Codex Automation 调用 Gmail 插件发送） ──
DIGEST_OUTPUT_DIR="${DIGEST_OUTPUT_DIR:-$LOG_DIR/digests}"
mkdir -p "$DIGEST_OUTPUT_DIR"
export EMAIL_TO="${CEPM_EMAIL_TO:-$EMAIL_TO}"
export DIGEST_OUTPUT_DIR

if ! python3 "$PIPELINE_DIR/email/digest_sender.py" \
    "data/cepm_latest.json" \
    "$SCAN_FROM" \
    "data/cepm_seen_dois.json" \
    "cepm" \
    --output-dir "$DIGEST_OUTPUT_DIR" \
    >> "$LOG_FILE" 2>&1; then
    echo "Digest export failed" >> "$LOG_FILE"
    exit 1
fi

# ── 通知 + 打开 App（仅有新论文时） ──
if [ "$NEW_COUNT" -gt 0 ] 2>/dev/null; then
    osascript -e "display notification \"CE/PM: ${NEW_COUNT} 篇新论文\" with title \"CE/PM Scout\" subtitle \"$TODAY\" sound name \"Glass\""
    [ -n "${DASHBOARD_URL:-}" ] && open "$DASHBOARD_URL"
fi

# ── 本地模式：不提交 main，不部署 gh-pages ──
echo "Local-only mode: skipped git commit/push and gh-pages deploy" >> "$LOG_FILE"
