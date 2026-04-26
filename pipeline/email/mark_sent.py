#!/usr/bin/env python3
"""Mark an exported Idea Scout digest as sent after Gmail delivery succeeds."""

from __future__ import annotations

import argparse
import json
import os
import sys
from datetime import datetime


def atomic_write_json(path: str, payload) -> None:
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    temp_path = f"{path}.{os.getpid()}.{int(datetime.now().timestamp())}.tmp"
    with open(temp_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(temp_path, path)


def load_json(path: str, fallback):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return fallback


def stamp_manifest_sent(manifest_path: str, manifest: dict, marked_count: int) -> None:
    now = datetime.now().astimezone().isoformat(timespec="seconds")
    manifest["sent_at"] = now
    manifest["marked_seen_count"] = marked_count
    manifest["sent_status"] = "sent"
    atomic_write_json(manifest_path, manifest)

    latest_path = manifest.get("latest_manifest_path")
    if latest_path:
        latest_path = os.path.abspath(latest_path)
        latest = load_json(latest_path, None)
        if isinstance(latest, dict) and latest.get("generated_at") == manifest.get("generated_at"):
            latest["sent_at"] = now
            latest["marked_seen_count"] = marked_count
            latest["sent_status"] = "sent"
            atomic_write_json(latest_path, latest)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", help="Path to logs/digests/<source>-latest.json or a timestamped manifest.")
    args = parser.parse_args()

    manifest_path = os.path.abspath(args.manifest)
    manifest = load_json(manifest_path, None)
    if not isinstance(manifest, dict):
        print(f"Cannot read digest manifest: {manifest_path}", file=sys.stderr)
        return 1

    if not manifest.get("send", False):
        print(f"No email was requested for {manifest.get('source', 'unknown')}; seen state unchanged.")
        return 0

    seen_path = manifest.get("seen_path")
    ids = [str(item).strip() for item in manifest.get("seen_ids", []) if str(item).strip()]
    if not seen_path:
        print("Manifest is missing seen_path.", file=sys.stderr)
        return 1
    if not ids:
        stamp_manifest_sent(manifest_path, manifest, 0)
        print("Manifest has no seen_ids; seen state unchanged, manifest stamped sent.")
        return 0

    seen_path = os.path.abspath(seen_path)
    seen = load_json(seen_path, [])
    if not isinstance(seen, list):
        print(f"{seen_path} must contain a JSON list.", file=sys.stderr)
        return 1

    merged = sorted(set(str(item).strip() for item in seen if str(item).strip()) | set(ids))
    atomic_write_json(seen_path, merged)
    stamp_manifest_sent(manifest_path, manifest, len(ids))

    print(f"Marked {len(ids)} {manifest.get('dedupe_key', 'ids')} as sent in {seen_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
