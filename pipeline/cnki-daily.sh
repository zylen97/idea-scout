#!/bin/bash
# Journal Scout — CNKI Daily Pipeline
# 由本地 launchd 触发，通过 CNKI RSS 抓取并用 Gmail API 发送

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
SCAN_TMP=""
cleanup() {
    [ -n "$SCAN_TMP" ] && [ -f "$SCAN_TMP" ] && rm -f "$SCAN_TMP"
    rmdir "$LOCKDIR" 2>/dev/null
}
trap cleanup EXIT

LOG_DIR="${LOG_DIR:-$REPO_DIR/logs}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/cnki-$(date +%Y%m%d-%H%M%S).log"
TODAY=$(date +%Y-%m-%d)
DASHBOARD_URL="${DASHBOARD_URL:-http://127.0.0.1:5174}"

# 设置 PATH
export PATH="$HOME/anaconda3/bin:$HOME/.local/bin:$HOME/develop/flutter/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# 加载本地配置（用于 EMAIL_TO / Gmail API）
if [ -n "${EMAIL_CONFIG_PATH:-}" ]; then
    if [ ! -f "$EMAIL_CONFIG_PATH" ]; then
        echo "ERROR: EMAIL_CONFIG_PATH does not exist: $EMAIL_CONFIG_PATH" >> "$LOG_FILE"
        exit 1
    fi
    source "$EMAIL_CONFIG_PATH"
fi
if [ -n "${IDEA_SCOUT_EMAIL_TO:-}" ]; then
    EMAIL_TO="$IDEA_SCOUT_EMAIL_TO"
    CNKI_EMAIL_TO="$IDEA_SCOUT_EMAIL_TO"
fi
export EMAIL_TO CNKI_EMAIL_TO
export GMAIL_TOKEN_PATH GMAIL_CREDENTIALS_PATH GMAIL_FROM GMAIL_SENDER_NAME SMTP_USER

echo "=== CNKI Daily Scan ===" >> "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"

# cd 到 repo 根目录（pipeline 和 data/ 在同一 repo）
cd "$REPO_DIR" || exit 1

# ── 本地正本：Dashboard 直接写 data/user_state.json ──
rm -f /tmp/idea_scout_user_state.json
cp data/user_state.json /tmp/idea_scout_user_state.json 2>/dev/null || true

export_failure_digest() {
    local reason="$1"
    DIGEST_OUTPUT_DIR="${DIGEST_OUTPUT_DIR:-$LOG_DIR/digests}"
    mkdir -p "$DIGEST_OUTPUT_DIR"
    python3 "$PIPELINE_DIR/email/failure_digest.py" \
        "cnki" \
        --reason "$reason" \
        --log-file "$LOG_FILE" \
        --scan-date "$TODAY" \
        --output-dir "$DIGEST_OUTPUT_DIR" \
        >> "$LOG_FILE" 2>&1 || true
}

parse_success_count() {
    echo "$1" | sed -n 's/.*Scan stats: \([0-9][0-9]*\)\/[0-9][0-9]* journals succeeded.*/\1/p' | tail -1
}

# ── 扫描（CNKI RSS，失败过半则重试一次） ──
run_cnki_scan() {
    local output_path="$1"
    set -o pipefail
    python3 "$PIPELINE_DIR/scanners/cnki_scanner.py" \
        --config "$REPO_DIR/config/cnki-journals.json" \
        --output "$output_path" \
        --days 30 \
        2>&1 | tee -a "$LOG_FILE"
}

SCAN_TMP=$(mktemp "$REPO_DIR/data/cnki_latest.json.tmp.XXXXXX") || exit 1
SCAN_OUTPUT=$(run_cnki_scan "$SCAN_TMP")
EXIT_CODE=$?
echo "Scan finished: $(date), exit code: $EXIT_CODE" >> "$LOG_FILE"

# 检查成功期刊数，不足 20 本则等 30 秒重试一次
JOURNAL_COUNT=$(parse_success_count "$SCAN_OUTPUT")
JOURNAL_COUNT=${JOURNAL_COUNT:-0}
FINAL_COUNT=$JOURNAL_COUNT
if [ "$JOURNAL_COUNT" -lt 20 ]; then
    echo "RETRY: only $JOURNAL_COUNT journals succeeded (<20), retrying in 30s..." >> "$LOG_FILE"
    sleep 30
    rm -f "$SCAN_TMP"
    SCAN_TMP=$(mktemp "$REPO_DIR/data/cnki_latest.json.tmp.XXXXXX") || exit 1
    SCAN_OUTPUT=$(run_cnki_scan "$SCAN_TMP")
    EXIT_CODE=$?
    echo "Retry scan finished: $(date), exit code: $EXIT_CODE" >> "$LOG_FILE"

    RETRY_COUNT=$(parse_success_count "$SCAN_OUTPUT")
    RETRY_COUNT=${RETRY_COUNT:-0}
    FINAL_COUNT=$RETRY_COUNT
    if [ "$RETRY_COUNT" -lt 20 ]; then
        REASON="CNKI scan failed: only $RETRY_COUNT journals succeeded after retry (minimum 20)."
        echo "ERROR: $REASON" >> "$LOG_FILE"
        export_failure_digest "$REASON"
        osascript -e 'display notification "CNKI scan failed, check logs" with title "CNKI Scout" subtitle "Failed" sound name "Basso"' || true
        exit 1
    fi
fi

if [ "$EXIT_CODE" -ne 0 ] || [ ! -s "$SCAN_TMP" ] || [ "$FINAL_COUNT" -lt 20 ]; then
    REASON="CNKI scan failed: exit_code=$EXIT_CODE, successful_journals=$FINAL_COUNT."
    echo "$REASON" >> "$LOG_FILE"
    export_failure_digest "$REASON"
    osascript -e 'display notification "CNKI scan failed, check logs" with title "CNKI Scout" subtitle "Failed" sound name "Basso"' || true
    exit 1
fi

mv "$SCAN_TMP" "data/cnki_latest.json"
SCAN_TMP=""

# ── 合并数据（累积到 cnki_papers.json，与 FT50/CEPM 架构一致） ──
python3 - "data/cnki_latest.json" "data/cnki_papers.json" "$TODAY" << 'PYEOF'
import json, sys

latest_path, papers_path, scan_date = sys.argv[1], sys.argv[2], sys.argv[3]

try:
    with open(latest_path, 'r') as f:
        new_papers = json.load(f)
    if isinstance(new_papers, dict) and 'papers' in new_papers:
        new_papers = new_papers['papers']
except Exception as e:
    print(f"Cannot read cnki_latest.json: {e}", file=sys.stderr)
    sys.exit(0)

for p in new_papers:
    p['scan_date'] = scan_date

try:
    with open(papers_path, 'r') as f:
        all_papers = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    all_papers = []

# CNKI 用 stable_id（md5(title|journal_id)）去重，因为 CNKI URL 每次扫描都会变
import hashlib
def _sid(p):
    s = p.get('stable_id', '')
    if s: return s
    return hashlib.md5(f"{p.get('title','')}|{p.get('journal_id','')}".encode('utf-8')).hexdigest()

# 加载 user_state.json 中已删除的 stable_id，避免已删除论文重新进入 Pending
deleted_sids = set()
try:
    with open('/tmp/idea_scout_user_state.json', 'r') as f:
        user_state = json.load(f)
    _raw = user_state.get('cnki', {}).get('deleted_dois', [])
    deleted_sids = set((x['id'] if isinstance(x, dict) else x) for x in _raw)
    # 同时排除 idea_papers 中的论文
    for ip in user_state.get('cnki', {}).get('idea_papers', []):
        tid = ip.get('tracking_id', '')
        if tid:
            deleted_sids.add(tid)
except (FileNotFoundError, json.JSONDecodeError):
    pass

sid_map = {_sid(p): p for p in all_papers if p.get('title')}
for p in new_papers:
    if p.get('title'):
        p['stable_id'] = _sid(p)
        sid_map[p['stable_id']] = p
# 过滤掉用户已删除/已加入Idea的论文
all_papers = [p for sid, p in sid_map.items() if sid not in deleted_sids]

from datetime import datetime, timedelta
cutoff = (datetime.now() - timedelta(days=60)).strftime('%Y-%m-%d')
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
papers = json.load(open('data/cnki_latest.json'))
if isinstance(papers, dict) and 'papers' in papers: papers = papers['papers']
try: seen = set(json.load(open('data/cnki_seen_titles.json')))
except: seen = set()
new = [p for p in papers if p.get('title') and p['title'] not in seen]
print(len(new))
" 2>/dev/null || echo "0")
echo "New papers (after dedup): $NEW_COUNT" >> "$LOG_FILE"

# ── 日报导出 + 本地 Gmail API 发送 ──
DIGEST_OUTPUT_DIR="${DIGEST_OUTPUT_DIR:-$LOG_DIR/digests}"
mkdir -p "$DIGEST_OUTPUT_DIR"
export EMAIL_TO="${CNKI_EMAIL_TO:-$EMAIL_TO}"
export DIGEST_OUTPUT_DIR GMAIL_TOKEN_PATH GMAIL_CREDENTIALS_PATH GMAIL_FROM GMAIL_SENDER_NAME SMTP_USER

if ! python3 "$PIPELINE_DIR/email/cnki_sender.py" \
    "data/cnki_latest.json" \
    "$TODAY" \
    "data/cnki_seen_titles.json" \
    --user-state "/tmp/idea_scout_user_state.json" \
    --output-dir "$DIGEST_OUTPUT_DIR" \
    >> "$LOG_FILE" 2>&1; then
    echo "Digest export failed" >> "$LOG_FILE"
    exit 1
fi

NEW_COUNT=$(python3 - "$DIGEST_OUTPUT_DIR/cnki-latest.json" << 'PYEOF'
import json, sys
try:
    print(int(json.load(open(sys.argv[1])).get('papers_count', 0)))
except Exception:
    print(0)
PYEOF
)

if ! python3 "$PIPELINE_DIR/email/send_manifest.py" \
    "$DIGEST_OUTPUT_DIR/cnki-latest.json" \
    >> "$LOG_FILE" 2>&1; then
    echo "Digest delivery failed" >> "$LOG_FILE"
    exit 1
fi

# ── 通知 + 打开 App（仅有新论文时） ──
if [ "$NEW_COUNT" -gt 0 ] 2>/dev/null; then
    osascript -e "display notification \"CNKI: ${NEW_COUNT} 篇新论文\" with title \"CNKI Scout\" subtitle \"$TODAY\" sound name \"Glass\""
    [ -n "${DASHBOARD_URL:-}" ] && open "$DASHBOARD_URL"
fi

# ── 本地模式：不提交 main，不部署 gh-pages ──
echo "Local-only mode: skipped git commit/push and gh-pages deploy" >> "$LOG_FILE"

# 清理 30 天前的旧日志
find "$LOG_DIR" -name "cnki-*.log" -mtime +30 -delete 2>/dev/null

echo "Done: $(date)" >> "$LOG_FILE"
