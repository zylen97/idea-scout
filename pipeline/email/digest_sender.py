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
    from datetime import date
    today = date.today().strftime('%Y-%m-%d')
    date_range = f'{scan_from} ~ {today}'
    # 按期刊分组
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
    tier_colors = {1: '#C25B3F', 2: '#B8963E', 3: '#5A8A6A'}
    tier_labels = {1: 'A', 2: 'B', 3: 'C'}

    # Source-specific branding (same warm brown theme)
    if source == 'cepm':
        header_color = '#6B5B4E'
        header_title = 'CE/PM Scout'
        footer_text = 'By ZYLEN - 每日 9:10 扫描建工/PM 期刊'
        show_tier = False
    else:
        header_color = '#8B7355'
        header_title = 'Idea Scout'
        footer_text = 'By ZYLEN - 每日 9:00 扫描 UTD24/FT50 顶刊'
        show_tier = True

    # ── 统计总表 ──
    summary_rows = ''
    for (tier, jid, jname), plist in sorted_journals:
        color = tier_colors.get(tier, '#5A8A6A')
        cat = tier_labels.get(tier, 'C')
        oa_count = sum(1 for p in plist if p.get('is_oa', False) or p.get('oa', False))
        oa_text = f' ({oa_count} OA)' if oa_count > 0 else ''
        cat_cell = f'<td style="padding: 4px 8px;"><span style="background: {color}; color: white; padding: 1px 6px; border-radius: 3px; font-size: 11px; font-weight: bold;">{cat}</span></td>' if show_tier else ''
        summary_rows += f"""
      <tr>
        {cat_cell}
        <td style="padding: 4px 8px; font-size: 13px;">{jid}</td>
        <td style="padding: 4px 8px; font-size: 13px; color: #6B6560;">{jname}</td>
        <td style="padding: 4px 8px; font-size: 13px; font-weight: 600; text-align: center;">{len(plist)}</td>
        <td style="padding: 4px 8px; font-size: 12px; color: #5A8A6A;">{oa_text}</td>
      </tr>"""

    html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: -apple-system, 'Segoe UI', sans-serif; background: #F5F3ED; padding: 20px; color: #2D2A26;">
<div style="max-width: 700px; margin: 0 auto;">

<div style="background: {header_color}; color: white; padding: 20px 24px; border-radius: 12px 12px 0 0;">
  <h1 style="margin: 0; font-size: 22px;">{header_title}</h1>
  <p style="margin: 6px 0 0; opacity: 0.9; font-size: 14px;">{date_range} · 共 {total} 篇 · {journal_count} 本期刊</p>
</div>

<div style="background: white; padding: 24px; border-radius: 0 0 12px 12px; border: 1px solid #D8D4CA; border-top: none;">


<!-- 统计总表 -->
<h2 style="font-size: 16px; margin: 0 0 12px; color: #2D2A26;">今日概览</h2>
<table style="width: 100%; border-collapse: collapse; margin-bottom: 24px; border: 1px solid #E8E6DC; border-radius: 8px;">
  <thead>
    <tr style="background: #F5F3ED;">
      {'<th style="padding: 6px 8px; text-align: left; font-size: 12px; color: #6B6560;">Cat</th>' if show_tier else ''}
      <th style="padding: 6px 8px; text-align: left; font-size: 12px; color: #6B6560;">期刊</th>
      <th style="padding: 6px 8px; text-align: left; font-size: 12px; color: #6B6560;">全称</th>
      <th style="padding: 6px 8px; text-align: center; font-size: 12px; color: #6B6560;">篇数</th>
      <th style="padding: 6px 8px; text-align: left; font-size: 12px; color: #6B6560;">OA</th>
    </tr>
  </thead>
  <tbody>{summary_rows}
    <tr style="background: #F5F3ED; font-weight: 600;">
      <td colspan="{'3' if show_tier else '2'}" style="padding: 6px 8px; font-size: 13px;">合计</td>
      <td style="padding: 6px 8px; font-size: 13px; text-align: center;">{total}</td>
      <td></td>
    </tr>
  </tbody>
</table>

<hr style="border: none; border-top: 1px solid #E8E6DC; margin: 20px 0;">

<!-- 论文详情 -->
<h2 style="font-size: 16px; margin: 0 0 16px; color: #2D2A26;">论文列表</h2>
"""

    for (tier, jid, jname), plist in sorted_journals:
        color = tier_colors.get(tier, '#5A8A6A')
        cat = tier_labels.get(tier, 'C')
        cat_badge = f'<span style="background: {color}; color: white; padding: 2px 8px; border-radius: 4px; font-size: 12px; font-weight: bold; margin-right: 8px;">{cat}</span>' if show_tier else ''
        section_color = color if show_tier else header_color
        html += f"""
<div style="margin-bottom: 24px;">
  <div style="display: flex; align-items: center; margin-bottom: 12px; border-bottom: 2px solid {section_color}; padding-bottom: 6px;">
    {cat_badge}
    <span style="font-weight: 600; font-size: 15px;">{jname}</span>
    <span style="color: #9B9488; margin-left: 8px; font-size: 13px;">({len(plist)}篇)</span>
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

            oa_badge = '<span style="background: #5A8A6A; color: white; padding: 1px 5px; border-radius: 3px; font-size: 10px; margin-left: 6px;">OA</span>' if is_oa else ''
            doi_link = f'<a href="{doi}" style="color: #8B7355; text-decoration: none; font-size: 12px;">DOI ↗</a>' if doi else ''
            authors_line = f'<div style="font-size: 12px; color: #9B9488; margin-bottom: 3px;">{authors_str}</div>' if authors_str else ''
            abstract_cn_block = f'<div style="font-size: 13px; color: #6B6560; line-height: 1.5; margin-bottom: 4px;"><span style="color: #8B7355; font-weight: 600; font-size: 11px; letter-spacing: 0.5px;">中文 · </span>{abstract_cn}</div>' if abstract_cn else ''
            abstract_en_block = f'<div style="font-size: 12px; color: #8B857D; line-height: 1.5; margin-bottom: 4px; padding-top: 2px;"><span style="color: #8B7355; font-weight: 600; font-size: 11px; letter-spacing: 0.5px;">EN · </span>{abstract_en}</div>' if abstract_en else ''

            html += f"""
  <div style="margin-bottom: 16px; padding-left: 12px; border-left: 3px solid #E8E6DC;">
    <div style="font-weight: 600; font-size: 14px; line-height: 1.4; margin-bottom: 2px;">{title_cn}{oa_badge}</div>
    <div style="font-size: 13px; color: #6B6560; line-height: 1.3; margin-bottom: 2px; font-style: italic;">{title_en}</div>
    {authors_line}
    {abstract_cn_block}
    {abstract_en_block}
    <div style="font-size: 12px; color: #9B9488;">{doi_link}</div>
  </div>
"""
        html += "</div>"

    import random
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
<p style="text-align: center; font-size: 13px; color: #8B7355; margin-top: 20px; padding-top: 16px; border-top: 1px solid #E8E6DC; font-style: italic;">「{quote}」</p>

<p style="text-align: center; font-size: 11px; color: #9B9488; margin-top: 8px;">{footer_text}</p>

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
