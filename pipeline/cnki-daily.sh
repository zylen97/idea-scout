#!/bin/bash
# Journal Scout — CNKI Daily Pipeline
# 由 launchd 触发，通过 CNKI RSS 抓取

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PIPELINE_DIR="$REPO_DIR/pipeline"
LOCAL_CONFIG="$REPO_DIR/config/local.sh"
[ -f "$LOCAL_CONFIG" ] && source "$LOCAL_CONFIG"

# ── 文件锁（防止睡眠唤醒后多脚本同时操作 git） ──
LOCKDIR="/tmp/idea_scout_git.lock"
LOCK_WAIT=0
while ! mkdir "$LOCKDIR" 2>/dev/null; do
    # 防腐：锁超过 10 分钟视为残留，强制清除
    if [ -d "$LOCKDIR" ] && [ "$(( $(date +%s) - $(stat -f %m "$LOCKDIR") ))" -gt 600 ]; then
        echo "WARN: stale lock detected (>10min), force removing" >> "${LOG_DIR:-/tmp}/journal-scout-lock.log"
        rmdir "$LOCKDIR" 2>/dev/null || rm -rf "$LOCKDIR"
        continue
    fi
    sleep 10
    LOCK_WAIT=$((LOCK_WAIT + 10))
    if [ $LOCK_WAIT -ge 300 ]; then
        echo "ERROR: lock wait timeout (5min), aborting" >> "${LOG_DIR:-/tmp}/journal-scout-lock.log"
        exit 1
    fi
done
trap 'rmdir "$LOCKDIR" 2>/dev/null' EXIT

LOG_DIR="${LOG_DIR:-$REPO_DIR/logs}"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/cnki-$(date +%Y%m%d-%H%M%S).log"
TODAY=$(date +%Y-%m-%d)
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 设置 PATH
export PATH="$HOME/anaconda3/bin:$HOME/.local/bin:$HOME/develop/flutter/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

# 加载配置（CNKI 不需要翻译 API，只用 SMTP 发邮件）
source "${EMAIL_CONFIG_PATH:?EMAIL_CONFIG_PATH not set}"

echo "=== CNKI Daily Scan ===" >> "$LOG_FILE"
echo "Started: $(date)" >> "$LOG_FILE"

# cd 到 repo 根目录（pipeline 和 data/ 在同一 repo）
cd "$REPO_DIR" || exit 1

# ── 同步 App 端最新 user_state（App 通过 GitHub API 写入 main） ──
# 必须在扫描前 pull，否则扫描产生的未提交文件会导致 rebase 失败
perl -e 'alarm 60; exec @ARGV' git pull --rebase origin main --quiet >> "$LOG_FILE" 2>&1 || {
    echo "WARN: git pull --rebase failed, falling back to merge" >> "$LOG_FILE"
    git rebase --abort 2>/dev/null
    perl -e 'alarm 60; exec @ARGV' git pull origin main --quiet >> "$LOG_FILE" 2>&1 || true
}
cp data/user_state.json /tmp/idea_scout_user_state.json 2>/dev/null

# ── 扫描（CNKI RSS，失败过半则重试一次） ──
run_cnki_scan() {
    set -o pipefail
    python3 "$PIPELINE_DIR/scanners/cnki_scanner.py" \
        --config "$REPO_DIR/config/cnki-journals.json" \
        --output "data/cnki_latest.json" \
        --days 30 \
        2>&1 | tee -a "$LOG_FILE"
}

SCAN_OUTPUT=$(run_cnki_scan)
EXIT_CODE=${PIPESTATUS[0]:-$?}
echo "Scan finished: $(date), exit code: $EXIT_CODE" >> "$LOG_FILE"

# 检查成功期刊数，不足 20 本则等 30 秒重试一次
JOURNAL_COUNT=$(echo "$SCAN_OUTPUT" | sed -n 's/.*from \([0-9]*\) journals.*/\1/p' | tail -1)
JOURNAL_COUNT=${JOURNAL_COUNT:-0}
if [ "$JOURNAL_COUNT" -lt 20 ]; then
    echo "RETRY: only $JOURNAL_COUNT journals succeeded (<20), retrying in 30s..." >> "$LOG_FILE"
    sleep 30
    SCAN_OUTPUT=$(run_cnki_scan)
    EXIT_CODE=${PIPESTATUS[0]:-$?}
    echo "Retry scan finished: $(date), exit code: $EXIT_CODE" >> "$LOG_FILE"

    # 重试后仍不足，发邮件提醒手动重跑
    RETRY_COUNT=$(echo "$SCAN_OUTPUT" | sed -n 's/.*from \([0-9]*\) journals.*/\1/p' | tail -1)
    RETRY_COUNT=${RETRY_COUNT:-0}
    if [ "$RETRY_COUNT" -lt 20 ]; then
        echo "NOTIFY: retry still only $RETRY_COUNT journals, sending alert email" >> "$LOG_FILE"
        export SMTP_SERVER SMTP_PORT SMTP_USER SMTP_PASS
        python3 -c "
import smtplib
from email.mime.text import MIMEText
import os
msg = MIMEText('CNKI scan failed after two attempts (journals succeeded: ${JOURNAL_COUNT} then ${RETRY_COUNT}/44). This may be caused by network issues.\n\nPlease re-run the pipeline manually.\n\nLog: ${LOG_FILE}', 'plain', 'utf-8')
msg['Subject'] = 'CNKI Scout scan failed - manual re-run required'
msg['From'] = os.environ['SMTP_USER']
msg['To'] = os.environ['SMTP_USER']
with smtplib.SMTP_SSL(os.environ['SMTP_SERVER'], int(os.environ['SMTP_PORT'])) as s:
    s.login(os.environ['SMTP_USER'], os.environ['SMTP_PASS'])
    s.send_message(msg)
print('Alert email sent')
" >> "$LOG_FILE" 2>&1 || echo "Alert email failed" >> "$LOG_FILE"
    fi
fi

if [ $EXIT_CODE -ne 0 ] || [ ! -s "data/cnki_latest.json" ]; then
    echo "Scan failed, aborting" >> "$LOG_FILE"
    osascript -e 'display notification "CNKI scan failed, check logs" with title "CNKI Scout" subtitle "Failed" sound name "Basso"'
    exit 1
fi

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

# ── 邮件推送 ──
export SMTP_SERVER SMTP_PORT SMTP_USER SMTP_PASS
export EMAIL_TO="${CNKI_EMAIL_TO:-$EMAIL_TO}"

python3 "$PIPELINE_DIR/email/cnki_sender.py" \
    "data/cnki_latest.json" \
    "$TODAY" \
    "data/cnki_seen_titles.json" \
    >> "$LOG_FILE" 2>&1 || echo "Email sending failed" >> "$LOG_FILE"

# ── 通知 + 打开 App（仅有新论文时） ──
if [ "$NEW_COUNT" -gt 0 ] 2>/dev/null; then
    osascript -e "display notification \"CNKI: ${NEW_COUNT} 篇新论文\" with title \"CNKI Scout\" subtitle \"$TODAY\" sound name \"Glass\""
    [ -n "${APP_URL:-}" ] && open "$APP_URL"
fi

# ── 推送到 GitHub + 部署 gh-pages（带超时保护） ──
git add data/cnki_latest.json data/cnki_papers.json data/cnki_seen_titles.json
git commit -m "cnki: $TODAY" 2>> "$LOG_FILE"

PUSH_OK=0
for _attempt in 1 2 3; do
    perl -e 'alarm 60; exec @ARGV' git push origin main >> "$LOG_FILE" 2>&1 && { PUSH_OK=1; break; }
    sleep 5
done
if [ $PUSH_OK -eq 0 ]; then
    echo "ERROR: git push main failed after 3 attempts" >> "$LOG_FILE"
    osascript -e 'display notification "git push main 超时/失败，数据未同步" with title "CNKI Scout" subtitle "Push Failed" sound name "Basso"'
fi

# 部署到 gh-pages
mkdir -p /tmp/idea_scout_all_data
cp data/*.json /tmp/idea_scout_all_data/
if ! git checkout gh-pages >> "$LOG_FILE" 2>&1; then
    echo "ERROR: git checkout gh-pages failed, skipping deploy" >> "$LOG_FILE"
    rm -rf /tmp/idea_scout_all_data
    echo "GitHub push done (gh-pages skipped)" >> "$LOG_FILE"
    find "$LOG_DIR" -name "cnki-*.log" -mtime +30 -delete 2>/dev/null
    echo "Done: $(date)" >> "$LOG_FILE"
    exit 0
fi
cp /tmp/idea_scout_all_data/*.json data/
git add data/
git commit -m "data: cnki $TODAY" 2>> "$LOG_FILE"

PUSH_OK=0
for _attempt in 1 2 3; do
    perl -e 'alarm 60; exec @ARGV' git push origin gh-pages >> "$LOG_FILE" 2>&1 && { PUSH_OK=1; break; }
    sleep 5
done
if [ $PUSH_OK -eq 0 ]; then
    echo "ERROR: git push gh-pages failed after 3 attempts" >> "$LOG_FILE"
    osascript -e 'display notification "gh-pages push 超时/失败，App 未更新" with title "CNKI Scout" subtitle "Push Failed" sound name "Basso"'
fi

git checkout main 2>> "$LOG_FILE"
rm -rf /tmp/idea_scout_all_data

echo "GitHub push done" >> "$LOG_FILE"

# 清理 30 天前的旧日志
find "$LOG_DIR" -name "cnki-*.log" -mtime +30 -delete 2>/dev/null

echo "Done: $(date)" >> "$LOG_FILE"
