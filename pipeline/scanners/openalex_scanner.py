#!/usr/bin/env python3
"""Idea Scout shared scan script — fetch papers from OpenAlex + translate via ChatAnywhere.
Used by both FT50 and CE/PM daily pipelines."""

import argparse
import concurrent.futures
import json
import os
import sys
import time
import urllib.parse
import urllib.request


def rebuild_abstract(inv_idx):
    if not inv_idx:
        return ""
    wp = []
    for word, positions in inv_idx.items():
        for pos in positions:
            wp.append((pos, word))
    wp.sort()
    return " ".join(w for _, w in wp)


# 标题匹配任一关键词即视为噪音，不入库
NOISE_PATTERNS = [
    "issue information",
    "correction to ",
    "erratum",
    "corrigendum",
    "retraction notice",
    "retraction:",
    "editorial board",
    "table of contents",
    "front cover",
    "back cover",
    "masthead",
    "reviewer acknowledgement",
    "list of reviewers",
    "books received",
    "call for papers",
    "in this issue",
]


def _is_noise(title):
    t = (title or "").lower().strip()
    return any(t.startswith(p) or p in t for p in NOISE_PATTERNS)


def fetch_papers(config, from_date, to_date):
    mailto = config["openalex_mailto"]
    journals = config["journals"]
    all_papers = []

    for j in journals:
        jid = j["id"]
        jname = j["name"]
        tier = j.get("tier", 1)
        oa_id = j["openalex_id"]

        url = (
            f"https://api.openalex.org/works?"
            f"filter=primary_location.source.id:{oa_id},"
            f"from_publication_date:{from_date},type:article"
            f"&sort=publication_date:desc&per_page=50&cursor=*"
            f"&mailto={mailto}"
        )

        while url:
            try:
                req = urllib.request.Request(url, headers={"User-Agent": "IdeaScout/1.0"})
                with urllib.request.urlopen(req, timeout=30) as resp:
                    data = json.loads(resp.read())
            except Exception as e:
                print(f"  ERROR {jid}: {e}", file=sys.stderr)
                break

            results = data.get("results", [])
            meta = data.get("meta", {})

            for r in results:
                abstract = rebuild_abstract(r.get("abstract_inverted_index"))

                pub_date = r.get("publication_date", "")
                if pub_date > to_date:
                    continue

                if _is_noise(r.get("title", "")):
                    continue

                authors = [
                    a.get("author", {}).get("display_name", "")
                    for a in r.get("authorships", [])
                    if a.get("author", {}).get("display_name")
                ]
                topics = [t.get("display_name", "") for t in r.get("topics", [])[:3]]

                oa_status = False
                pdf_url = ""
                if r.get("open_access"):
                    oa_status = r["open_access"].get("is_oa", False)
                    pdf_url = r["open_access"].get("oa_url", "") or ""

                all_papers.append({
                    "journal_id": jid,
                    "journal_name": jname,
                    "title": r.get("title", ""),
                    "authors": authors,
                    "doi": r.get("doi", ""),
                    "date": pub_date,
                    "abstract": abstract,
                    "topics": topics,
                    "cited_by": r.get("cited_by_count", 0),
                    "oa": oa_status,
                    "pdf_url": pdf_url,
                    "tier": tier,
                    "title_cn": "",
                    "abstract_cn": "",
                })

            next_cursor = meta.get("next_cursor")
            if next_cursor and len(results) > 0:
                base = url.split("&cursor=")[0]
                url = f"{base}&cursor={urllib.parse.quote(next_cursor)}"
                time.sleep(0.3)
            else:
                url = None

        count = sum(1 for p in all_papers if p["journal_id"] == jid)
        if count > 0:
            print(f"  {jid}: {count} papers")
        time.sleep(0.3)

    return all_papers


def translate_papers(papers, api_key):
    api_url = "https://api.chatanywhere.tech/v1/chat/completions"

    def translate(text):
        if not text or len(text.strip()) < 5:
            return text
        body = json.dumps({
            "model": "gpt-4o-mini",
            "messages": [
                {"role": "system", "content": "你是学术翻译助手。将以下英文学术文本翻译为中文，保持学术术语准确，语言流畅自然。只返回翻译结果。"},
                {"role": "user", "content": text},
            ],
            "temperature": 0.3,
        }).encode()

        for attempt in range(3):
            try:
                req = urllib.request.Request(api_url, data=body, headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {api_key}",
                })
                with urllib.request.urlopen(req, timeout=60) as resp:
                    result = json.loads(resp.read())
                    return result["choices"][0]["message"]["content"].strip()
            except Exception as e:
                if attempt < 2:
                    time.sleep(2)
                else:
                    print(f"Translation failed: {str(e)[:80]}", file=sys.stderr)
                    return ""

    print("Translating titles...")
    titles = [p["title"] for p in papers]
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as ex:
        title_results = list(ex.map(translate, titles))
    for i, t in enumerate(title_results):
        papers[i]["title_cn"] = t

    print("Translating abstracts...")
    abstracts = [p["abstract"] for p in papers]
    with concurrent.futures.ThreadPoolExecutor(max_workers=50) as ex:
        abstract_results = list(ex.map(translate, abstracts))
    for i, a in enumerate(abstract_results):
        papers[i]["abstract_cn"] = a

    translated = sum(1 for p in papers if p["title_cn"] and p["abstract_cn"])
    print(f"Translated: {translated}/{len(papers)}")
    return papers


def main():
    parser = argparse.ArgumentParser(description="Idea Scout shared scan script")
    parser.add_argument("--config", required=True, help="Path to journals config JSON")
    parser.add_argument("--from", dest="from_date", required=True, help="Start date YYYY-MM-DD")
    parser.add_argument("--to", dest="to_date", required=True, help="End date YYYY-MM-DD")
    parser.add_argument("--output", required=True, help="Output JSON path")
    args = parser.parse_args()

    api_key = os.environ.get("CHATANYWHERE_API_KEY", "")
    if not api_key:
        print("ERROR: CHATANYWHERE_API_KEY not set", file=sys.stderr)
        sys.exit(1)

    with open(args.config) as f:
        config = json.load(f)

    source = config.get("source", "unknown")
    print(f"Scanning {len(config['journals'])} {source} journals: {args.from_date} ~ {args.to_date}")

    papers = fetch_papers(config, args.from_date, args.to_date)
    print(f"Fetched: {len(papers)} papers from {len(set(p['journal_id'] for p in papers))} journals")

    if not papers:
        print("No papers found, writing empty output")
        with open(args.output, "w") as f:
            json.dump([], f)
        return

    papers = translate_papers(papers, api_key)

    with open(args.output, "w") as f:
        json.dump(papers, f, ensure_ascii=False)

    print(f"Output: {args.output} ({len(papers)} papers)")


if __name__ == "__main__":
    main()
