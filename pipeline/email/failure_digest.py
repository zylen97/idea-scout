#!/usr/bin/env python3
"""Export an Idea Scout failure manifest for automation diagnostics."""

from __future__ import annotations

import argparse
import os

from export_utils import recipients_from_env, write_digest


LABELS = {
    "ft50": "Idea Scout",
    "cepm": "CE/PM Scout",
    "cnki": "CNKI Scout",
}


def failure_html(label: str, reason: str, log_file: str) -> str:
    return f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#F5F4EE;color:#1F1E1D;padding:24px;">
  <div style="max-width:680px;margin:0 auto;background:#FAF9F5;border:1px solid #D9D5C9;border-radius:8px;padding:20px;">
    <h1 style="font-size:20px;margin:0 0 8px;">{label} scan failed</h1>
    <p style="margin:0 0 12px;color:#6F6E69;">{reason}</p>
    <p style="margin:0;color:#6F6E69;font-family:ui-monospace,SFMono-Regular,Menlo,monospace;font-size:12px;">{log_file}</p>
  </div>
</body>
</html>"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", choices=sorted(LABELS))
    parser.add_argument("--reason", required=True)
    parser.add_argument("--log-file", required=True)
    parser.add_argument("--scan-date", default="")
    parser.add_argument("--output-dir", default=os.environ.get("DIGEST_OUTPUT_DIR", "logs/digests"))
    args = parser.parse_args()

    label = LABELS[args.source]
    log_file = os.path.abspath(args.log_file)
    exported = write_digest(args.output_dir, args.source, {
        "send": False,
        "status": "failure",
        "reason": args.reason,
        "source_label": label,
        "subject": "",
        "to": recipients_from_env("EMAIL_TO"),
        "body_format": "html",
        "latest_path": "",
        "seen_path": "",
        "seen_ids": [],
        "dedupe_key": "",
        "papers_count": 0,
        "journals_count": 0,
        "scan_date": args.scan_date,
        "log_path": log_file,
    }, failure_html(label, args.reason, log_file))
    print(f"Failure manifest exported: {exported['latest_manifest_path']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
