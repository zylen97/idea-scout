#!/usr/bin/env python3
"""Journal Scout digest email: load papers from latest.json, group by journal, send HTML email."""

import json, sys, os, smtplib, base64, time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

GMAIL_TOKEN_PATH = os.environ.get('GMAIL_TOKEN_PATH', os.path.join(os.path.dirname(__file__), 'gmail_token.json'))
SENDER_NAME = os.environ.get('SENDER_NAME', 'Journal Scout')

def load_new_papers(latest_path, seen_path):
    """加载本次扫描结果，去掉上次已见过的论文（按 DOI 差集）"""
    with open(latest_path, 'r') as f:
        papers = json.load(f)
    if isinstance(papers, dict) and 'papers' in papers:
        papers = papers['papers']

    # 读取已知 DOI 集合
    seen_dois = set()
    try:
        with open(seen_path, 'r') as f:
            seen_dois = set(json.load(f))
    except (FileNotFoundError, json.JSONDecodeError):
        pass

    # 筛选新论文：有 DOI 的按 DOI 去重，无 DOI 的一律当新论文推送（宁可多推不漏推）
    new_papers = [p for p in papers if not p.get('doi') or p['doi'] not in seen_dois]

    return new_papers, seen_dois

def build_email_html(papers, scan_from, source='ft50'):
    """Render the daily digest email — visual language aligned with the
    static-HTML workbench at https://zylen97.github.io/idea-scout/.

    Email-safe HTML: inline styles, no <style> blocks, no flexbox tricks,
    table-based layout for Outlook compatibility, system font stack only.
    """
    from datetime import date
    import random

    today = date.today().strftime('%Y-%m-%d')
    date_range = f'{scan_from} → {today}'

    # ── Workbench palette (mirrors index.html :root) ──────────────────
    BG       = '#F5F4EE'   # page background
    SURFACE  = '#FAF9F5'   # card
    BG2      = '#EEEBE2'   # table-head row
    INK      = '#1F1E1D'
    INK2     = '#3D3D3A'
    INK3     = '#6F6E69'
    INK4     = '#A09F99'
    LINE     = '#D9D5C9'
    LINE2    = '#E7E3D8'
    ACCENT   = '#D97757'   # Claude orange — CTA only
    OK       = '#6B7F58'   # OA badge

    # Per-source theming (matches stats-chart bar colors in workbench)
    SRC_THEME = {
        'ft50': ('#B08A5E', 'Idea Scout',  'FT50/UTD24', '每日 9:00 扫描 UTD24/FT50 顶刊'),
        'cepm': ('#2E7D6F', 'CE/PM Scout', 'CE/PM',      '每日 9:10 扫描建工/PM 期刊'),
    }
    theme_color, header_title, source_label, footer_text = SRC_THEME.get(source, SRC_THEME['ft50'])
    show_tier = (source != 'cepm')   # CE/PM is flat — no tier ranking

    # Tier chips (workbench-style monochrome dark→light)
    TIER_BG    = {1: INK,  2: INK2, 3: INK4}
    TIER_LABEL = {1: 'A',  2: 'B',  3: 'C'}

    # Font stack with Chinese fallback
    FONT = ("-apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', "
            "'Hiragino Sans GB', 'Microsoft YaHei', 'Helvetica Neue', sans-serif")
    MONO = "'SF Mono', Menlo, Consolas, 'Courier New', monospace"

    # ── Group papers by (tier, jid, jname) ───────────────────────────
    by_journal = {}
    for p in papers:
        jid = p.get('journal_id', 'Unknown')
        jname = p.get('journal_name', jid)
        tier = p.get('tier', 3)
        key = (tier, jid, jname)
        by_journal.setdefault(key, []).append(p)
    sorted_journals = sorted(by_journal.items(), key=lambda x: (x[0][0], x[0][1]))

    total = len(papers)
    journal_count = len(by_journal)

    def chip(text, bg, fg='#FFFFFF', font=MONO, size='10px'):
        return (f'<span style="display:inline-block;background:{bg};color:{fg};'
                f'padding:2px 6px;border-radius:3px;font-family:{font};'
                f'font-size:{size};font-weight:600;letter-spacing:.04em;'
                f'line-height:1.2;">{text}</span>')

    def tier_chip(tier):
        return chip(TIER_LABEL.get(tier, 'C'), TIER_BG.get(tier, INK4))

    # ── Summary rows ──────────────────────────────────────────────────
    summary_rows = ''
    for (tier, jid, jname), plist in sorted_journals:
        oa_count = sum(1 for p in plist if p.get('is_oa', False) or p.get('oa', False))
        oa_text = f'+{oa_count} OA' if oa_count > 0 else ''
        cat_cell = (f'<td style="padding:6px 10px;border-bottom:1px solid {LINE2};">'
                    f'{tier_chip(tier)}</td>') if show_tier else ''
        summary_rows += f"""
      <tr>
        {cat_cell}
        <td style="padding:6px 10px;font-family:{MONO};font-size:11px;color:{INK};font-weight:600;border-bottom:1px solid {LINE2};">{jid}</td>
        <td style="padding:6px 10px;font-size:13px;color:{INK2};border-bottom:1px solid {LINE2};">{jname}</td>
        <td style="padding:6px 10px;font-family:{MONO};font-size:12px;color:{INK};font-weight:700;text-align:right;border-bottom:1px solid {LINE2};">{len(plist)}</td>
        <td style="padding:6px 10px;font-family:{MONO};font-size:11px;color:{OK};border-bottom:1px solid {LINE2};">{oa_text}</td>
      </tr>"""

    # ── HTML scaffold ────────────────────────────────────────────────
    html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background:{BG};font-family:{FONT};color:{INK};-webkit-font-smoothing:antialiased;">
<div style="max-width:720px;margin:0 auto;padding:20px 16px;">

<!-- Header banner -->
<div style="background:{theme_color};color:#FFFFFF;padding:22px 24px;border-radius:10px 10px 0 0;">
  <div style="font-family:{MONO};font-size:10px;letter-spacing:.12em;text-transform:uppercase;opacity:.78;margin-bottom:6px;">{source_label}</div>
  <h1 style="margin:0;font-size:22px;font-weight:700;letter-spacing:-.01em;">{header_title}</h1>
  <p style="margin:6px 0 0;font-size:13px;opacity:.85;font-family:{MONO};letter-spacing:.02em;">{date_range} · {total} papers · {journal_count} journals</p>
</div>

<!-- Card body -->
<div style="background:{SURFACE};padding:22px 24px 24px;border-radius:0 0 10px 10px;border:1px solid {LINE};border-top:none;">

<!-- Summary table -->
<div style="font-family:{MONO};font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:{INK3};margin:0 0 8px;">今日概览 · summary</div>
<table style="width:100%;border-collapse:collapse;margin-bottom:24px;border:1px solid {LINE};border-radius:6px;overflow:hidden;">
  <thead>
    <tr style="background:{BG2};">
      {f'<th style="padding:7px 10px;text-align:left;font-family:{MONO};font-size:9.5px;letter-spacing:.08em;color:{INK3};font-weight:500;text-transform:uppercase;border-bottom:1px solid {LINE};">Tier</th>' if show_tier else ''}
      <th style="padding:7px 10px;text-align:left;font-family:{MONO};font-size:9.5px;letter-spacing:.08em;color:{INK3};font-weight:500;text-transform:uppercase;border-bottom:1px solid {LINE};">JID</th>
      <th style="padding:7px 10px;text-align:left;font-family:{MONO};font-size:9.5px;letter-spacing:.08em;color:{INK3};font-weight:500;text-transform:uppercase;border-bottom:1px solid {LINE};">Journal</th>
      <th style="padding:7px 10px;text-align:right;font-family:{MONO};font-size:9.5px;letter-spacing:.08em;color:{INK3};font-weight:500;text-transform:uppercase;border-bottom:1px solid {LINE};">N</th>
      <th style="padding:7px 10px;text-align:left;font-family:{MONO};font-size:9.5px;letter-spacing:.08em;color:{INK3};font-weight:500;text-transform:uppercase;border-bottom:1px solid {LINE};">OA</th>
    </tr>
  </thead>
  <tbody>{summary_rows}
    <tr style="background:{BG2};">
      <td colspan="{'3' if show_tier else '2'}" style="padding:7px 10px;font-family:{MONO};font-size:11px;color:{INK};font-weight:600;letter-spacing:.04em;">TOTAL</td>
      <td style="padding:7px 10px;font-family:{MONO};font-size:13px;color:{INK};font-weight:700;text-align:right;">{total}</td>
      <td></td>
    </tr>
  </tbody>
</table>

<!-- Per-paper sections -->
<div style="font-family:{MONO};font-size:10px;letter-spacing:.1em;text-transform:uppercase;color:{INK3};margin:0 0 12px;">论文列表 · papers</div>
"""

    for (tier, jid, jname), plist in sorted_journals:
        section_chip = (tier_chip(tier) + '&nbsp;') if show_tier else ''
        jid_chip_html = chip(jid, BG2, INK, MONO, '10px')
        html += f"""
<div style="margin-bottom:22px;">
  <div style="padding:8px 0 6px;border-bottom:2px solid {theme_color};margin-bottom:10px;">
    {section_chip}{jid_chip_html}
    <span style="font-weight:600;font-size:14.5px;color:{INK};margin-left:8px;">{jname}</span>
    <span style="color:{INK4};margin-left:6px;font-size:12px;font-family:{MONO};">· {len(plist)} 篇</span>
  </div>
"""
        for p in plist:
            title_cn = p.get('title_cn', '')
            title_en = p.get('title', '')
            authors = p.get('authors', [])
            authors_str = ', '.join(authors) if authors else ''
            abstract_cn = p.get('abstract_cn', '')
            abstract_en = p.get('abstract', '')
            doi = p.get('doi', '')
            is_oa = p.get('is_oa', False) or p.get('oa', False)

            oa_badge = (f'&nbsp;{chip("OA", OK, "#FFFFFF", MONO, "9px")}' if is_oa else '')
            doi_link = (f'<a href="{doi}" style="color:{theme_color};text-decoration:none;font-family:{MONO};font-size:11px;">DOI ↗</a>'
                        if doi else '')
            authors_line = (f'<div style="font-family:{MONO};font-size:11px;color:{INK4};margin-bottom:4px;">{authors_str}</div>'
                            if authors_str else '')
            abstract_cn_block = (f'<div style="font-size:12.5px;color:{INK2};line-height:1.6;margin-bottom:4px;">'
                                 f'<span style="color:{INK4};font-family:{MONO};font-size:9.5px;letter-spacing:.08em;text-transform:uppercase;">中文 ·</span> {abstract_cn}</div>'
                                 if abstract_cn else '')
            abstract_en_block = (f'<div style="font-size:11.5px;color:{INK3};line-height:1.6;margin-bottom:4px;">'
                                 f'<span style="color:{INK4};font-family:{MONO};font-size:9.5px;letter-spacing:.08em;text-transform:uppercase;">EN ·</span> {abstract_en}</div>'
                                 if abstract_en else '')

            html += f"""
  <div style="margin-bottom:16px;padding-left:12px;border-left:3px solid {theme_color};">
    <div style="font-weight:600;font-size:14px;line-height:1.45;color:{INK};margin-bottom:3px;">{title_cn}{oa_badge}</div>
    <div style="font-size:12.5px;color:{INK3};line-height:1.4;margin-bottom:3px;font-style:italic;">{title_en}</div>
    {authors_line}
    {abstract_cn_block}
    {abstract_en_block}
    <div style="margin-top:4px;">{doi_link}</div>
  </div>
"""
        html += "</div>"

    quotes = [
        "路虽远，行则将至；事虽难，做则必成。",
        "不积跬步，无以至千里。",
        "今天的积累，是明天的底气。",
        "保持好奇心，它是学术创新的源泉。",
        "每一篇论文都是一次对话，和过去的自己，和未来的读者。",
        "慢慢来，比较快。",
        "想都是问题，做才是答案。",
        "你读过的每一篇文献，都不会白读。",
        "把大目标拆成小任务，然后一个一个干掉。",
        "科研是马拉松，不是百米冲刺。",
        "灵感来自积累，突破来自坚持。",
        "与其完美计划，不如先动手写。",
        "今天比昨天进步一点，就够了。",
        "好的研究者不是什么都懂，而是知道去哪里找答案。",
        "休息也是生产力的一部分。",
        "做难而正确的事。",
        "你的研究，终将照亮某个角落。",
        "把每一次审稿意见，都当作免费的学术指导。",
        "写不出来的时候，先去读。",
        "坚持记录，坚持思考，坚持输出。",
    ]
    quote = random.choice(quotes)

    html += f"""
<p style="text-align:center;font-size:13px;color:{theme_color};margin:24px 0 8px;padding-top:18px;border-top:1px solid {LINE2};font-style:italic;letter-spacing:.02em;">「{quote}」</p>

<p style="text-align:center;font-size:10.5px;color:{INK4};margin:8px 0 0;font-family:{MONO};letter-spacing:.04em;">By ZYLEN · {footer_text}</p>

</div></div></body></html>"""

    return html, total, journal_count

def send_email_api(recipients, subject, html_body):
    """Gmail API via HTTPS（主力）"""
    import requests

    with open(GMAIL_TOKEN_PATH) as f:
        token = json.load(f)

    # refresh_token → access_token
    resp = requests.post(token['token_uri'], data={
        'client_id': token['client_id'],
        'client_secret': token['client_secret'],
        'refresh_token': token['refresh_token'],
        'grant_type': 'refresh_token'
    }, timeout=15)
    resp.raise_for_status()
    access_token = resp.json()['access_token']

    # 构造邮件
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
    scan_date = sys.argv[2]  # 显示用日期
    seen_path = sys.argv[3] if len(sys.argv) > 3 else 'data/seen_dois.json'
    source = sys.argv[4] if len(sys.argv) > 4 else 'ft50'

    smtp_server = os.environ.get('SMTP_SERVER', 'smtp.gmail.com')
    smtp_port = int(os.environ.get('SMTP_PORT', '465'))
    smtp_user = os.environ['SMTP_USER']
    smtp_pass = os.environ['SMTP_PASS']
    recipients = os.environ['EMAIL_TO'].split(',')

    papers, seen_dois = load_new_papers(latest_path, seen_path)

    if not papers:
        print('No new papers, skipping email')
        sys.exit(0)

    html_body, total, jcount = build_email_html(papers, scan_date, source)

    from datetime import date
    today = date.today().strftime('%Y-%m-%d')
    if source == 'cepm':
        subject = f'CE/PM Scout {today} - {total}篇新论文'
    else:
        subject = f'Idea Scout {today} - {total}篇新论文'

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

    # 邮件发送成功后才更新 seen_dois
    all_dois = seen_dois | {p['doi'] for p in papers if p.get('doi')}
    with open(seen_path, 'w') as f:
        json.dump(sorted(all_dois), f)

    print(f'Email sent to {", ".join(recipients)}: {total} new papers ({source})')
