#!/usr/bin/env python3
"""Report missed Idea Scout daily jobs for local delivery diagnostics."""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import dataclass
from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo


REPO_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
DIGEST_DIR = os.path.join(REPO_DIR, "logs", "digests")


@dataclass(frozen=True)
class SourceJob:
    source: str
    label: str
    due: time
    script: str
    latest_manifest: str
    seen_path: str


JOBS = [
    SourceJob("ft50", "FT50/UTD24", time(9, 0), "pipeline/ft50-daily.sh", "logs/digests/ft50-latest.json", "data/seen_dois.json"),
    SourceJob("cepm", "CE/PM", time(9, 10), "pipeline/cepm-daily.sh", "logs/digests/cepm-latest.json", "data/cepm_seen_dois.json"),
    SourceJob("cnki", "CNKI", time(9, 20), "pipeline/cnki-daily.sh", "logs/digests/cnki-latest.json", "data/cnki_seen_titles.json"),
]


def shanghai_tz():
    try:
        return ZoneInfo("Asia/Shanghai")
    except Exception:
        return timezone(timedelta(hours=8), name="Asia/Shanghai")


def load_json(path: str, fallback):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except (FileNotFoundError, json.JSONDecodeError):
        return fallback


def parse_dt(value: str | None, tz) -> datetime | None:
    if not value:
        return None
    try:
        parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    if parsed.tzinfo is None:
        parsed = parsed.replace(tzinfo=tz)
    return parsed.astimezone(tz)


def today_due(now: datetime, job: SourceJob) -> datetime:
    return datetime.combine(now.date(), job.due, tzinfo=now.tzinfo)


def seen_contains_all(manifest: dict) -> bool:
    ids = [str(item).strip() for item in manifest.get("seen_ids", []) if str(item).strip()]
    if not ids:
        return bool(manifest.get("sent_at"))
    seen_path = os.path.abspath(manifest.get("seen_path") or "")
    if not seen_path:
        return False
    seen = load_json(seen_path, [])
    if not isinstance(seen, list):
        return False
    seen_set = {str(item).strip() for item in seen if str(item).strip()}
    return set(ids).issubset(seen_set)


def status_for(now: datetime, job: SourceJob, grace_minutes: int) -> dict:
    due_at = today_due(now, job)
    eligible_at = due_at + timedelta(minutes=grace_minutes)
    latest_manifest = os.path.join(REPO_DIR, job.latest_manifest)
    script_path = os.path.join(REPO_DIR, job.script)

    base = {
        "source": job.source,
        "label": job.label,
        "due_at": due_at.isoformat(timespec="minutes"),
        "eligible_at": eligible_at.isoformat(timespec="minutes"),
        "script": job.script,
        "script_path": script_path,
        "run_command": f"bash {job.script}",
        "latest_manifest": job.latest_manifest,
        "latest_manifest_path": latest_manifest,
        "seen_path": os.path.join(REPO_DIR, job.seen_path),
    }

    if now < eligible_at:
        return {**base, "status": "not_due", "reason": f"Catch-up opens after {eligible_at.isoformat(timespec='minutes')}."}

    manifest = load_json(latest_manifest, None)
    if not isinstance(manifest, dict):
        return {
            **base,
            "status": "blocked",
            "reason": "Local launchd has not produced a latest digest manifest.",
        }

    generated_at = parse_dt(manifest.get("generated_at"), now.tzinfo)
    if not generated_at or generated_at.date() != now.date():
        return {
            **base,
            "status": "blocked",
            "reason": "Latest digest manifest is not from today; local launchd did not produce today's scan output.",
            "manifest_generated_at": manifest.get("generated_at"),
        }

    if manifest.get("status") == "failure":
        return {
            **base,
            "status": "blocked",
            "reason": str(manifest.get("reason", "Scan failed.")),
            "manifest": latest_manifest,
            "manifest_generated_at": generated_at.isoformat(timespec="seconds"),
            "log_path": manifest.get("log_path", ""),
        }

    send = bool(manifest.get("send"))
    if not send:
        reason = str(manifest.get("reason", "send=false"))
        ok_no_papers = "No new papers" in reason
        return {
            **base,
            "status": "complete" if ok_no_papers else "blocked",
            "reason": reason,
            "manifest": latest_manifest,
            "manifest_generated_at": generated_at.isoformat(timespec="seconds"),
        }

    if manifest.get("sent_at") or seen_contains_all(manifest):
        return {
            **base,
            "status": "complete",
            "reason": "Digest generated today and delivery is marked complete.",
            "manifest": latest_manifest,
            "manifest_generated_at": generated_at.isoformat(timespec="seconds"),
            "sent_at": manifest.get("sent_at", ""),
        }

    return {
        **base,
        "status": "needs_send",
        "reason": "Digest generated today but local Gmail delivery is not marked complete.",
        "manifest": latest_manifest,
        "html_path": manifest.get("html_path", ""),
        "subject": manifest.get("subject", ""),
        "to": manifest.get("to", []),
        "mark_sent_command": manifest.get("mark_sent_command", ""),
        "papers_count": manifest.get("papers_count", 0),
        "manifest_generated_at": generated_at.isoformat(timespec="seconds"),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", choices=["all", "ft50", "cepm", "cnki"], default="all")
    parser.add_argument("--grace-minutes", type=int, default=30)
    parser.add_argument("--now", help="Override current time for tests, ISO format.")
    args = parser.parse_args()

    tz = shanghai_tz()
    now = parse_dt(args.now, tz) if args.now else datetime.now(tz)
    if now is None:
        print("Invalid --now value.", file=sys.stderr)
        return 2

    jobs = JOBS if args.source == "all" else [job for job in JOBS if job.source == args.source]
    tasks = [status_for(now, job, args.grace_minutes) for job in jobs]
    payload = {
        "now": now.isoformat(timespec="seconds"),
        "timezone": "Asia/Shanghai",
        "repo_dir": REPO_DIR,
        "grace_minutes": args.grace_minutes,
        "tasks": tasks,
        "pending": [task for task in tasks if task["status"] in {"needs_run", "needs_send", "blocked"}],
    }
    json.dump(payload, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
