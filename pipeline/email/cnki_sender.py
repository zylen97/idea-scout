#!/usr/bin/env python3
"""CNKI Scout digest email: load papers from cnki_latest.json, group by journal, send HTML email."""

import json, sys, os, smtplib, random, base64, time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import date

GMAIL_TOKEN_PATH = os.environ.get('GMAIL_TOKEN_PATH', os.path.join(os.path.dirname(__file__), 'gmail_token.json'))
SENDER_NAME = os.environ.get('SENDER_NAME', 'Journal Scout')


def load_new_papers(latest_path, seen_path):
    """加载论文，去掉已推送的（按标题去重，因为中文论文大多没有 DOI）"""
    with open(latest_path, 'r') as f:
        papers = json.load(f)

    seen_titles = set()
    try:
        with open(seen_path, 'r') as f:
            seen_titles = set(json.load(f))
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    new_papers = [p for p in papers if p.get('title') and p['title'] not in seen_titles]
    return new_papers, seen_titles


def _load_cnki_categories():
    """Load jid → category map from cnki-journals.json.
    Tries (1) alongside the script (production deploy layout), then
    (2) repo's config/ directory (development / repo-checkout layout)."""
    here = os.path.dirname(__file__)
    candidates = [
        os.path.join(here, 'cnki-journals.json'),
        os.path.join(here, '..', '..', 'config', 'cnki-journals.json'),
    ]
    for path in candidates:
        try:
            with open(path, 'r', encoding='utf-8') as f:
                cfg = json.load(f)
            lst = cfg.get('journals', cfg if isinstance(cfg, list) else [])
            return {j['id']: j.get('category', '其他') for j in lst}
        except FileNotFoundError:
            continue
        except Exception:
            return {}
    return {}


def build_email_html(papers, scan_date):
    """CNKI digest email — visual language aligned with the static-HTML
    workbench. Adds category grouping (管理A / 管理B1 / 管理B2 / 工程 / 其他)
    that mirrors the workbench sidebar.
    """
    # ── Workbench palette (mirrors index.html :root) ──────────────────
    BG       = '#F5F4EE'
    SURFACE  = '#FAF9F5'
    BG2      = '#EEEBE2'
    INK      = '#1F1E1D'
    INK2     = '#3D3D3A'
    INK3     = '#6F6E69'
    INK4     = '#A09F99'
    LINE     = '#D9D5C9'
    LINE2    = '#E7E3D8'
    ACCENT   = '#D97757'
    THEME    = '#C25B3F'   # CNKI brick-red, matches stats-chart bar color

    FONT = ("-apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', "
            "'Hiragino Sans GB', 'Microsoft YaHei', 'Helvetica Neue', sans-serif")
    MONO = "'SF Mono', Menlo, Consolas, 'Courier New', monospace"

    WORKBENCH_URL = 'https://zylen97.github.io/idea-scout/'

    CAT_ORDER = ['管理A', '管理B1', '管理B2', '工程', '其他']
    CAT_BG    = {'管理A': INK, '管理B1': INK2, '管理B2': INK3, '工程': INK4, '其他': INK4}
    JID_TO_CAT = _load_cnki_categories()

    def cat_of(p):
        return JID_TO_CAT.get(p.get('journal_id', ''), '其他')

    # ── Group: category → journal → papers ───────────────────────────
    by_cat = {}
    for p in papers:
        cat = cat_of(p)
        jid = p.get('journal_id', 'Unknown')
        jname = p.get('journal_name', jid)
        by_cat.setdefault(cat, {}).setdefault((jid, jname), []).append(p)

    total = len(papers)
    journal_count = sum(len(j) for j in by_cat.values())
    today = date.today().strftime('%Y-%m-%d')

    def chip(text, bg, fg='#FFFFFF', font=MONO, size='10px'):
        return (f'<span style="display:inline-block;background:{bg};color:{fg};'
                f'padding:2px 6px;border-radius:3px;font-family:{font};'
                f'font-size:{size};font-weight:600;letter-spacing:.04em;'
                f'line-height:1.2;">{text}</span>')

    def cat_chip(cat):
        return chip(cat, CAT_BG.get(cat, INK4), '#FFFFFF', FONT, '10.5px')

    # ── Summary table: per-category counts ───────────────────────────
    summary_rows = ''
    for cat in CAT_ORDER:
        if cat not in by_cat: continue
        n_papers = sum(len(plist) for plist in by_cat[cat].values())
        n_journals = len(by_cat[cat])
        summary_rows += f"""
      <tr>
        <td style="padding:7px 10px;border-bottom:1px solid {LINE2};">{cat_chip(cat)}</td>
        <td style="padding:7px 10px;font-size:13px;color:{INK2};border-bottom:1px solid {LINE2};">{n_journals} 本期刊</td>
        <td style="padding:7px 10px;font-family:{MONO};font-size:13px;color:{INK};font-weight:700;text-align:right;border-bottom:1px solid {LINE2};">{n_papers}</td>
      </tr>"""

    html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:{BG};font-family:{FONT};color:{INK};-webkit-font-smoothing:antialiased;">
<div style="max-width:720px;margin:0 auto;padding:20px 16px;">

<!-- Header banner -->
<div style="background:{THEME};color:#FFFFFF;padding:22px 24px;border-radius:10px 10px 0 0;">
  <div style="font-family:{MONO};font-size:10px;letter-spacing:.12em;text-transform:uppercase;opacity:.78;margin-bottom:6px;">CNKI</div>
  <h1 style="margin:0;font-size:22px;font-weight:700;letter-spacing:-.01em;">CNKI Scout</h1>
  <p style="margin:6px 0 0;font-size:13px;opacity:.85;font-family:{MONO};letter-spacing:.02em;">{scan_date} → {today} · {total} papers · {journal_count} journals</p>
</div>

<!-- CTA strip -->
<div style="background:{SURFACE};border-left:1px solid {LINE};border-right:1px solid {LINE};padding:12px 24px;display:block;">
  <a href="{WORKBENCH_URL}" style="display:inline-block;background:{ACCENT};color:#FFFFFF;text-decoration:none;padding:7px 14px;border-radius:6px;font-size:12px;font-weight:600;letter-spacing:.01em;">📑 在工作台浏览 / 标记 →</a>
  <span style="color:{INK4};font-size:11px;margin-left:10px;font-family:{MONO};">{WORKBENCH_URL}</span>
</div>

<!-- Card body -->
<div style="background:{SURFACE};padding:22px 24px 24px;border-radius:0 0 10px 10px;border:1px solid {LINE};border-top:none;">

<!-- Summary -->
<div style="font-family:{MONO};font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:{INK3};margin:0 0 8px;">今日概览 · summary</div>
<table style="width:100%;border-collapse:collapse;margin-bottom:24px;border:1px solid {LINE};border-radius:6px;overflow:hidden;">
  <thead>
    <tr style="background:{BG2};">
      <th style="padding:7px 10px;text-align:left;font-family:{MONO};font-size:9.5px;letter-spacing:.08em;color:{INK3};font-weight:500;text-transform:uppercase;border-bottom:1px solid {LINE};">Category</th>
      <th style="padding:7px 10px;text-align:left;font-family:{MONO};font-size:9.5px;letter-spacing:.08em;color:{INK3};font-weight:500;text-transform:uppercase;border-bottom:1px solid {LINE};">Journals</th>
      <th style="padding:7px 10px;text-align:right;font-family:{MONO};font-size:9.5px;letter-spacing:.08em;color:{INK3};font-weight:500;text-transform:uppercase;border-bottom:1px solid {LINE};">N</th>
    </tr>
  </thead>
  <tbody>{summary_rows}
    <tr style="background:{BG2};">
      <td colspan="2" style="padding:7px 10px;font-family:{MONO};font-size:11px;color:{INK};font-weight:600;letter-spacing:.04em;">TOTAL</td>
      <td style="padding:7px 10px;font-family:{MONO};font-size:13px;color:{INK};font-weight:700;text-align:right;">{total}</td>
    </tr>
  </tbody>
</table>

<!-- Per-category sections -->
<div style="font-family:{MONO};font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:{INK3};margin:0 0 12px;">论文列表 · papers</div>
"""

    for cat in CAT_ORDER:
        if cat not in by_cat: continue
        cat_papers = sum(len(plist) for plist in by_cat[cat].values())
        # Category section header
        html += f"""
<div style="margin-bottom:8px;padding:6px 0;border-bottom:1.5px dashed {LINE};">
  {cat_chip(cat)}
  <span style="color:{INK3};margin-left:8px;font-size:11.5px;font-family:{MONO};">{cat_papers} papers</span>
</div>
"""
        sorted_journals = sorted(by_cat[cat].items(), key=lambda x: x[0][0])
        for (jid, jname), plist in sorted_journals:
            jid_chip = chip(jid, BG2, INK, MONO, '10px')
            html += f"""
<div style="margin-bottom:20px;">
  <div style="padding:8px 0 6px;border-bottom:2px solid {THEME};margin-bottom:10px;">
    {jid_chip}
    <span style="font-weight:600;font-size:14.5px;color:{INK};margin-left:8px;">{jname}</span>
    <span style="color:{INK4};margin-left:6px;font-size:12px;font-family:{MONO};">· {len(plist)} 篇</span>
  </div>
"""
            for p in plist:
                title = p.get('title', '')
                authors = p.get('authors', [])
                authors_str = ', '.join(authors) if authors else ''
                abstract = p.get('abstract', '')
                link = p.get('link', '')

                authors_line = (f'<div style="font-family:{MONO};font-size:11px;color:{INK4};margin-bottom:4px;">{authors_str}</div>'
                                if authors_str else '')
                link_html = (f'<a href="{link}" style="color:{THEME};text-decoration:none;font-family:{MONO};font-size:11px;">知网链接 ↗</a>'
                             if link else '')
                abstract_block = (f'<div style="font-size:12.5px;color:{INK2};line-height:1.6;margin-bottom:4px;">{abstract}</div>'
                                  if abstract else '')

                html += f"""
  <div style="margin-bottom:16px;padding-left:12px;border-left:3px solid {THEME};">
    <div style="font-weight:600;font-size:14px;line-height:1.45;color:{INK};margin-bottom:3px;">{title}</div>
    {authors_line}
    {abstract_block}
    <div style="margin-top:4px;">{link_html}</div>
  </div>
"""
            html += "</div>"

    quotes = [
        "路虽远，行则将至；事虽难，做则必成。",
        "不积跬步，无以至千里。",
        "今天的积累，是明天的底气。",
        "慢慢来，比较快。",
        "做难而正确的事。",
        "把每一次审稿意见，都当作免费的学术指导。",
        "保持好奇心，它是学术创新的源泉。",
    ]
    quote = random.choice(quotes)

    html += f"""
<p style="text-align:center;font-size:13px;color:{THEME};margin:24px 0 8px;padding-top:18px;border-top:1px solid {LINE2};font-style:italic;letter-spacing:.02em;">「{quote}」</p>

<p style="text-align:center;font-size:10.5px;color:{INK4};margin:8px 0 0;font-family:{MONO};letter-spacing:.04em;">
  By ZYLEN · 每日 9:20 扫描中文核心期刊 (CNKI RSS) ·
  <a href="{WORKBENCH_URL}" style="color:{INK3};text-decoration:underline;">Open Workbench</a>
</p>

</div></div></body></html>"""

    return html, total, journal_count


def send_email_api(recipients, subject, html_body):
    """Gmail API via HTTPS（主力）"""
    import requests

    with open(GMAIL_TOKEN_PATH) as f:
        token = json.load(f)

    resp = requests.post(token['token_uri'], data={
        'client_id': token['client_id'],
        'client_secret': token['client_secret'],
        'refresh_token': token['refresh_token'],
        'grant_type': 'refresh_token'
    }, timeout=15)
    resp.raise_for_status()
    access_token = resp.json()['access_token']

    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = f'{SENDER_NAME} <{os.environ.get("SMTP_USER", "noreply@example.com")}>'
    msg['Bcc'] = ', '.join(recipients)
    msg.attach(MIMEText(html_body, 'html', 'utf-8'))

    raw = base64.urlsafe_b64encode(msg.as_bytes()).decode()

    resp = requests.post(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/send',
        headers={'Authorization': f'Bearer {access_token}'},
        json={'raw': raw},
        timeout=30
    )
    resp.raise_for_status()


def send_email_smtp(smtp_server, smtp_port, smtp_user, smtp_pass, recipients, subject, html_body):
    """Gmail SMTP（fallback）"""
    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = f'{SENDER_NAME} <{smtp_user}>'
    msg['Bcc'] = ', '.join(recipients)
    msg.attach(MIMEText(html_body, 'html', 'utf-8'))

    for attempt in range(3):
        try:
            if smtp_port == 465:
                with smtplib.SMTP_SSL(smtp_server, smtp_port, timeout=30) as server:
                    server.login(smtp_user, smtp_pass)
                    server.sendmail(smtp_user, recipients, msg.as_string())
            else:
                with smtplib.SMTP(smtp_server, smtp_port, timeout=30) as server:
                    server.starttls()
                    server.login(smtp_user, smtp_pass)
                    server.sendmail(smtp_user, recipients, msg.as_string())
            return
        except (TimeoutError, OSError) as e:
            if attempt < 2:
                time.sleep(10)
            else:
                raise


if __name__ == '__main__':
    latest_path = sys.argv[1]
    scan_date = sys.argv[2]
    seen_path = sys.argv[3] if len(sys.argv) > 3 else 'data/cnki_seen_titles.json'

    smtp_server = os.environ.get('SMTP_SERVER', 'smtp.gmail.com')
    smtp_port = int(os.environ.get('SMTP_PORT', '465'))
    smtp_user = os.environ['SMTP_USER']
    smtp_pass = os.environ['SMTP_PASS']
    recipients = os.environ['EMAIL_TO'].split(',')

    papers, seen_titles = load_new_papers(latest_path, seen_path)

    if not papers:
        print('No new papers, skipping email')
        sys.exit(0)

    today = date.today().strftime('%Y-%m-%d')
    html_body, total, jcount = build_email_html(papers, scan_date)
    subject = f'CNKI Scout {today} - {total}篇中文新论文'

    # 主力：Gmail API（HTTPS），fallback：SMTP
    sent = False
    if os.path.exists(GMAIL_TOKEN_PATH):
        try:
            send_email_api(recipients, subject, html_body)
            print(f'[Gmail API] ', end='')
            sent = True
        except Exception as e:
            print(f'Gmail API failed ({e}), falling back to SMTP...', file=sys.stderr)

    if not sent:
        send_email_smtp(smtp_server, smtp_port, smtp_user, smtp_pass, recipients, subject, html_body)
        print(f'[SMTP] ', end='')

    # 成功后更新 seen_titles
    all_titles = seen_titles | {p['title'] for p in papers if p.get('title')}
    with open(seen_path, 'w') as f:
        json.dump(sorted(all_titles), f, ensure_ascii=False)

    print(f'Email sent to {", ".join(recipients)}: {total} new papers (cnki)')
