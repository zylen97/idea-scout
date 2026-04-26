#!/usr/bin/env python3
"""Utilities for exporting Idea Scout digests for local Gmail API delivery."""

from __future__ import annotations

import json
import os
from datetime import datetime


SCHEMA = "idea_scout_digest.v1"


def split_recipients(raw: str | None) -> list[str]:
    return [item.strip() for item in (raw or "").split(",") if item.strip()]


def recipients_from_env(var_name: str = "EMAIL_TO") -> list[str]:
    return split_recipients(os.environ.get(var_name, ""))


def atomic_write_text(path: str, text: str) -> None:
    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    temp_path = f"{path}.{os.getpid()}.{int(datetime.now().timestamp())}.tmp"
    with open(temp_path, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(temp_path, path)


def atomic_write_json(path: str, payload: dict) -> None:
    atomic_write_text(path, json.dumps(payload, ensure_ascii=False, indent=2) + "\n")


def no_new_html(source_label: str, reason: str) -> str:
    return f"""<!DOCTYPE html>
<html>
<head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;background:#F5F4EE;color:#1F1E1D;padding:24px;">
  <div style="max-width:680px;margin:0 auto;background:#FAF9F5;border:1px solid #D9D5C9;border-radius:8px;padding:20px;">
    <h1 style="font-size:20px;margin:0 0 8px;">{source_label}</h1>
    <p style="margin:0;color:#6F6E69;">{reason}</p>
  </div>
</body>
</html>"""


def write_digest(output_dir: str, source: str, manifest: dict, html_body: str | None) -> dict:
    output_dir = os.path.abspath(output_dir)
    os.makedirs(output_dir, exist_ok=True)

    now = datetime.now().astimezone()
    stamp = now.strftime("%Y%m%d-%H%M%S")
    generated_at = now.isoformat(timespec="seconds")
    base = f"{source}-{stamp}"

    html_path = os.path.join(output_dir, f"{base}.html")
    manifest_path = os.path.join(output_dir, f"{base}.json")
    latest_html_path = os.path.join(output_dir, f"{source}-latest.html")
    latest_manifest_path = os.path.join(output_dir, f"{source}-latest.json")

    body = html_body if html_body is not None else no_new_html(
        manifest.get("source_label", source.upper()),
        manifest.get("reason", "No new papers."),
    )
    write_html = str(body).strip()
    atomic_write_text(html_path, write_html)
    atomic_write_text(latest_html_path, write_html)

    payload = {
        "schema": SCHEMA,
        "generated_at": generated_at,
        "delivery": "local-gmail-api",
        **manifest,
        "source": source,
        "html_path": html_path,
        "manifest_path": manifest_path,
        "latest_html_path": latest_html_path,
        "latest_manifest_path": latest_manifest_path,
    }
    mark_sent_script = payload.pop("mark_sent_script", "")
    if mark_sent_script:
        payload["mark_sent_command"] = f"python3 {mark_sent_script} {manifest_path}"

    atomic_write_json(manifest_path, payload)
    atomic_write_json(latest_manifest_path, payload)
    return payload
