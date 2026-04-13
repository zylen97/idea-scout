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


def build_email_html(papers, scan_date):
    by_journal = {}
    for p in papers:
        jname = p.get('journal_name', 'Unknown')
        by_journal.setdefault(jname, []).append(p)

    sorted_journals = sorted(by_journal.items(), key=lambda x: x[0])
    total = len(papers)
    journal_count = len(by_journal)
    header_color = '#4A6B8A'
    today = date.today().strftime('%Y-%m-%d')

    summary_rows = ''
    for jname, plist in sorted_journals:
        summary_rows += f"""
      <tr>
        <td style="padding: 4px 8px; font-size: 13px;">{jname}</td>
        <td style="padding: 4px 8px; font-size: 13px; font-weight: 600; text-align: center;">{len(plist)}</td>
      </tr>"""

    html = f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: -apple-system, 'Segoe UI', sans-serif; background: #F5F3ED; padding: 20px; color: #2D2A26;">
<div style="max-width: 700px; margin: 0 auto;">

<div style="background: {header_color}; color: white; padding: 20px 24px; border-radius: 12px 12px 0 0;">
  <h1 style="margin: 0; font-size: 22px;">CNKI Scout</h1>
  <p style="margin: 6px 0 0; opacity: 0.9; font-size: 14px;">{scan_date} ~ {today} - {total} 篇 - {journal_count} 本期刊</p>
</div>

<div style="background: white; padding: 24px; border-radius: 0 0 12px 12px; border: 1px solid #D8D4CA; border-top: none;">

<h2 style="font-size: 16px; margin: 0 0 12px; color: #2D2A26;">今日概览</h2>
<table style="width: 100%; border-collapse: collapse; margin-bottom: 24px; border: 1px solid #E8E6DC; border-radius: 8px;">
  <thead>
    <tr style="background: #F5F3ED;">
      <th style="padding: 6px 8px; text-align: left; font-size: 12px; color: #6B6560;">期刊</th>
      <th style="padding: 6px 8px; text-align: center; font-size: 12px; color: #6B6560;">篇数</th>
    </tr>
  </thead>
  <tbody>{summary_rows}
    <tr style="background: #F5F3ED; font-weight: 600;">
      <td style="padding: 6px 8px; font-size: 13px;">合计</td>
      <td style="padding: 6px 8px; font-size: 13px; text-align: center;">{total}</td>
    </tr>
  </tbody>
</table>

<hr style="border: none; border-top: 1px solid #E8E6DC; margin: 20px 0;">

<h2 style="font-size: 16px; margin: 0 0 16px; color: #2D2A26;">论文列表</h2>
"""

    for jname, plist in sorted_journals:
        html += f"""
<div style="margin-bottom: 24px;">
  <div style="display: flex; align-items: center; margin-bottom: 12px; border-bottom: 2px solid {header_color}; padding-bottom: 6px;">
    <span style="font-weight: 600; font-size: 15px;">{jname}</span>
    <span style="color: #9B9488; margin-left: 8px; font-size: 13px;">({len(plist)}篇)</span>
  </div>
"""
        for p in plist:
            title = p.get('title', '')
            authors = p.get('authors', [])
            authors_str = ', '.join(authors) if authors else ''
            abstract = p.get('abstract', '')
            link = p.get('link', '')

            authors_line = f'<div style="font-size: 12px; color: #9B9488; margin-bottom: 3px;">{authors_str}</div>' if authors_str else ''
            link_html = f'<a href="{link}" style="color: {header_color}; text-decoration: none; font-size: 12px;">知网链接</a>' if link else ''

            html += f"""
  <div style="margin-bottom: 16px; padding-left: 12px; border-left: 3px solid #E8E6DC;">
    <div style="font-weight: 600; font-size: 14px; line-height: 1.4; margin-bottom: 2px;">{title}</div>
    {authors_line}
    <div style="font-size: 13px; color: #6B6560; line-height: 1.5; margin-bottom: 4px;">{abstract}</div>
    <div style="font-size: 12px; color: #9B9488;">{link_html}</div>
  </div>
"""
        html += "</div>"

    quotes = [
        "路虽远，行则将至；事虽难，做则必成。",
        "不积跬步，无以至千里。",
        "今天的积累，是明天的底气。",
        "慢慢来，比较快。",
        "做难而正确的事。",
    ]
    quote = random.choice(quotes)

    html += f"""
<p style="text-align: center; font-size: 13px; color: {header_color}; margin-top: 20px; padding-top: 16px; border-top: 1px solid #E8E6DC; font-style: italic;">{quote}</p>

<p style="text-align: center; font-size: 11px; color: #9B9488; margin-top: 8px;">By ZYLEN - 每日 9:20 扫描中文核心期刊 (CNKI RSS)</p>

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
