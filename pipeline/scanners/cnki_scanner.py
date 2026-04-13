#!/usr/bin/env python3
"""CNKI RSS Scanner — 从知网 RSS 抓取中文期刊最新论文，生成 App 数据和邮件推送。"""

import argparse
import hashlib
import json
import re
import sys
import time
import urllib.request
import html as html_lib
from datetime import datetime, timedelta


def make_stable_id(title, journal_id):
    """Generate stable ID from title + journal_id (MD5 hash, UTF-8 safe)."""
    raw = f"{title}|{journal_id}"
    return hashlib.md5(raw.encode("utf-8")).hexdigest()


def fetch_rss(journal_id, journal_name, rss_base_url, rss_suffix=""):
    """Fetch and parse CNKI RSS for a journal."""
    url = f"{rss_base_url}{journal_id}{rss_suffix}"
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
        })
        with urllib.request.urlopen(req, timeout=15) as resp:
            content = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  ERROR {journal_id} ({journal_name}): {e}", file=sys.stderr)
        return []

    items = re.findall(r"<item>(.*?)</item>", content, re.DOTALL)
    papers = []

    for item in items:
        title_m = re.search(r"<title>([^<]+)</title>", item)
        link_m = re.search(r"<link>([^<]+)</link>", item)
        author_m = re.search(r"<author>([^<]*)</author>", item)
        desc_m = re.search(r"<description>([^<]*)</description>", item)
        date_m = re.search(r"<pubDate>([^<]+)</pubDate>", item)

        title = html_lib.unescape(title_m.group(1).strip()) if title_m else ""
        if not title:
            continue

        link = html_lib.unescape(link_m.group(1).strip()) if link_m else ""
        authors = author_m.group(1).strip().rstrip(";") if author_m else ""
        abstract = html_lib.unescape(desc_m.group(1).strip()) if desc_m else ""
        pub_date_str = date_m.group(1).strip() if date_m else ""

        # Parse date
        date_iso = ""
        if pub_date_str:
            try:
                dt = datetime.strptime(pub_date_str, "%a, %d %b %Y %H:%M:%S %Z")
                date_iso = dt.strftime("%Y-%m-%d")
            except ValueError:
                try:
                    dt = datetime.strptime(pub_date_str[:10], "%Y-%m-%d")
                    date_iso = dt.strftime("%Y-%m-%d")
                except ValueError:
                    pass

        papers.append({
            "journal_id": journal_id,
            "journal_name": journal_name,
            "title": title,
            "authors": [a.strip() for a in authors.split(";") if a.strip()],
            "date": date_iso,
            "abstract": abstract,
            "link": link,
            "doi": "",
        })

    return papers


def main():
    parser = argparse.ArgumentParser(description="CNKI RSS Scanner")
    parser.add_argument("--config", required=True, help="Path to cnki-journals.json")
    parser.add_argument("--output", required=True, help="Output JSON path")
    parser.add_argument("--days", type=int, default=30, help="Only include papers from last N days")
    args = parser.parse_args()

    with open(args.config) as f:
        config = json.load(f)

    rss_base = config.get("rss_base_url", "https://rss.cnki.net/knavi/rss/")
    rss_suffix = config.get("rss_suffix", "")
    journals = config["journals"]
    cutoff = (datetime.now() - timedelta(days=args.days)).strftime("%Y-%m-%d")

    print(f"Scanning {len(journals)} CNKI journals (last {args.days} days, cutoff: {cutoff})")

    # Category to tier mapping
    tier_map = {"管理A": 1, "管理B1": 2, "管理B2": 3, "工程": 3, "其他": 3}

    all_papers = []
    for j in journals:
        papers = fetch_rss(j["id"], j["name"], rss_base, rss_suffix)
        tier = tier_map.get(j.get("category", ""), 3)
        for p in papers:
            p["_tier"] = tier
        recent = [p for p in papers if not p["date"] or p["date"] >= cutoff]
        if recent:
            print(f"  {j['id']:6s} {j['name']}: {len(recent)} papers")
        all_papers.extend(recent)
        time.sleep(0.3)

    print(f"Fetched: {len(all_papers)} papers from {len(set(p['journal_id'] for p in all_papers))} journals")

    if not all_papers:
        print("No papers found")
        with open(args.output, "w") as f:
            json.dump([], f)
        return

    # Normalize to App-compatible format (same as FT50/CE/PM Paper model)
    normalized = []
    for p in all_papers:
        normalized.append({
            "journal_id": p["journal_id"],
            "journal_name": p["journal_name"],
            "title": p["title"],
            "title_cn": p["title"],
            "authors": p["authors"],
            "doi": p.get("link", ""),
            "date": p["date"],
            "abstract": p["abstract"],
            "abstract_cn": p["abstract"],
            "topics": [],
            "cited_by": 0,
            "oa": False,
            "pdf_url": "",
            "tier": p.get("_tier", 3),
            "scan_date": datetime.now().strftime("%Y-%m-%d"),
            "stable_id": make_stable_id(p["title"], p["journal_id"]),
        })

    with open(args.output, "w") as f:
        json.dump(normalized, f, ensure_ascii=False)

    print(f"Output: {args.output} ({len(normalized)} papers)")


if __name__ == "__main__":
    main()
