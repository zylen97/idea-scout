#!/usr/bin/env python3
"""Send an exported Idea Scout digest through the local Gmail API OAuth token."""

from __future__ import annotations

import argparse
import base64
from email.message import EmailMessage
from email.utils import formataddr
import json
import os
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request


DEFAULT_TOKEN_URI = "https://oauth2.googleapis.com/token"
GMAIL_SEND_URL = "https://gmail.googleapis.com/gmail/v1/users/me/messages/send"


def load_json(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    if not isinstance(data, dict):
        raise ValueError(f"{path} must contain a JSON object.")
    return data


def split_recipients(raw: str | list[str] | None) -> list[str]:
    if isinstance(raw, list):
        items = raw
    else:
        items = str(raw or "").split(",")
    return [str(item).strip() for item in items if str(item).strip()]


def credentials_from_file(path: str) -> dict:
    data = load_json(path)
    if "installed" in data and isinstance(data["installed"], dict):
        return data["installed"]
    if "web" in data and isinstance(data["web"], dict):
        return data["web"]
    return data


def load_oauth_config(token_path: str, credentials_path: str | None) -> dict:
    token = load_json(token_path)
    refresh_token = token.get("refresh_token")
    if not refresh_token:
        raise ValueError(f"{token_path} is missing refresh_token.")

    client_id = token.get("client_id")
    client_secret = token.get("client_secret")
    token_uri = token.get("token_uri") or DEFAULT_TOKEN_URI

    if (not client_id or not client_secret) and credentials_path:
        credentials = credentials_from_file(credentials_path)
        client_id = client_id or credentials.get("client_id")
        client_secret = client_secret or credentials.get("client_secret")
        token_uri = token_uri or credentials.get("token_uri") or DEFAULT_TOKEN_URI

    if not client_id or not client_secret:
        raise ValueError("Gmail OAuth client_id/client_secret are missing.")

    return {
        "client_id": client_id,
        "client_secret": client_secret,
        "refresh_token": refresh_token,
        "token_uri": token_uri,
    }


def refresh_access_token(oauth: dict) -> str:
    body = urllib.parse.urlencode({
        "client_id": oauth["client_id"],
        "client_secret": oauth["client_secret"],
        "refresh_token": oauth["refresh_token"],
        "grant_type": "refresh_token",
    }).encode("utf-8")
    request = urllib.request.Request(
        oauth["token_uri"],
        data=body,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Gmail OAuth refresh failed: HTTP {exc.code}: {detail}") from exc

    access_token = payload.get("access_token")
    if not access_token:
        raise RuntimeError("Gmail OAuth refresh response did not include access_token.")
    return access_token


def build_message(manifest: dict, html_body: str, sender: str, sender_name: str) -> EmailMessage:
    subject = str(manifest.get("subject") or "").strip()
    recipients = split_recipients(manifest.get("to"))
    if not subject:
        raise ValueError("Digest manifest is missing subject.")
    if not recipients:
        raise ValueError("Digest manifest has no recipients.")
    if not sender:
        raise ValueError("Set GMAIL_FROM or SMTP_USER before sending.")

    source_label = str(manifest.get("source_label") or "Idea Scout")
    dashboard_url = os.environ.get("DASHBOARD_URL", "http://127.0.0.1:5174")
    plain = (
        f"{subject}\n\n"
        f"{source_label} generated {manifest.get('papers_count', 0)} new papers.\n"
        f"Dashboard: {dashboard_url}\n"
    )

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = formataddr((sender_name or source_label, sender))
    message["To"] = ", ".join(recipients)
    message["X-Idea-Scout-Source"] = str(manifest.get("source", "unknown"))
    message.set_content(plain)
    message.add_alternative(html_body, subtype="html")
    return message


def send_gmail_message(message: EmailMessage, access_token: str) -> dict:
    raw = base64.urlsafe_b64encode(message.as_bytes()).decode("ascii")
    payload = json.dumps({"raw": raw}).encode("utf-8")
    request = urllib.request.Request(
        GMAIL_SEND_URL,
        data=payload,
        headers={
            "Authorization": f"Bearer {access_token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"Gmail send failed: HTTP {exc.code}: {detail}") from exc


def mark_sent(manifest: dict, manifest_arg: str) -> None:
    mark_script = os.path.join(os.path.dirname(__file__), "mark_sent.py")
    manifest_path = manifest.get("manifest_path") or manifest_arg
    result = subprocess.run(
        [sys.executable, mark_script, os.path.abspath(str(manifest_path))],
        check=False,
        text=True,
        capture_output=True,
    )
    if result.stdout:
        print(result.stdout.strip())
    if result.stderr:
        print(result.stderr.strip(), file=sys.stderr)
    if result.returncode != 0:
        raise RuntimeError(f"mark_sent.py failed with exit code {result.returncode}.")


def atomic_write_json(path: str, payload: dict) -> None:
    directory = os.path.dirname(path)
    if directory:
        os.makedirs(directory, exist_ok=True)
    temp_path = f"{path}.{os.getpid()}.tmp"
    with open(temp_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=2)
        f.write("\n")
    os.replace(temp_path, path)


def stamp_delivery_metadata(manifest: dict, manifest_arg: str, sent: dict) -> dict:
    updates = {
        "delivery": "local-gmail-api",
        "gmail_message_id": sent.get("id", ""),
        "gmail_thread_id": sent.get("threadId", ""),
    }
    manifest.update(updates)
    paths = [manifest.get("manifest_path") or manifest_arg, manifest.get("latest_manifest_path")]
    for path in paths:
        if not path:
            continue
        abs_path = os.path.abspath(str(path))
        try:
            current = load_json(abs_path)
        except (FileNotFoundError, json.JSONDecodeError, ValueError):
            continue
        if current.get("generated_at") == manifest.get("generated_at"):
            current.update(updates)
            atomic_write_json(abs_path, current)
    return manifest


def validate_manifest(manifest_path: str, manifest: dict) -> tuple[bool, str]:
    if manifest.get("sent_at"):
        return False, f"Already sent at {manifest.get('sent_at')}."
    if not manifest.get("send", False):
        return False, str(manifest.get("reason") or "send=false")

    html_path = os.path.abspath(str(manifest.get("html_path") or ""))
    if not html_path or not os.path.isfile(html_path):
        raise ValueError(f"HTML body does not exist: {html_path}")
    if not split_recipients(manifest.get("to")):
        raise ValueError("Digest manifest has no recipients.")
    if not str(manifest.get("subject") or "").strip():
        raise ValueError("Digest manifest is missing subject.")
    return True, manifest_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", help="Path to logs/digests/<source>-latest.json or a timestamped manifest.")
    parser.add_argument("--dry-run", action="store_true", help="Validate config and manifest without sending email.")
    parser.add_argument("--force", action="store_true", help="Send even if manifest is already marked sent.")
    args = parser.parse_args()

    manifest_path = os.path.abspath(args.manifest)
    manifest = load_json(manifest_path)

    if args.force:
        manifest.pop("sent_at", None)
    should_send, reason = validate_manifest(manifest_path, manifest)
    if not should_send:
        print(f"No Gmail send needed for {manifest.get('source', 'unknown')}: {reason}")
        return 0

    token_path = os.environ.get("GMAIL_TOKEN_PATH", "").strip()
    credentials_path = os.environ.get("GMAIL_CREDENTIALS_PATH", "").strip()
    if not token_path:
        raise SystemExit("GMAIL_TOKEN_PATH is required for local Gmail API delivery.")
    token_path = os.path.abspath(os.path.expanduser(token_path))
    credentials_path = os.path.abspath(os.path.expanduser(credentials_path)) if credentials_path else None
    if not os.path.isfile(token_path):
        raise SystemExit(f"GMAIL_TOKEN_PATH does not exist: {token_path}")
    if credentials_path and not os.path.isfile(credentials_path):
        raise SystemExit(f"GMAIL_CREDENTIALS_PATH does not exist: {credentials_path}")

    html_path = os.path.abspath(str(manifest["html_path"]))
    with open(html_path, "r", encoding="utf-8") as f:
        html_body = f.read()

    sender = os.environ.get("GMAIL_FROM") or os.environ.get("SMTP_USER") or ""
    sender_name = os.environ.get("GMAIL_SENDER_NAME") or str(manifest.get("source_label") or "Idea Scout")
    message = build_message(manifest, html_body, sender.strip(), sender_name.strip())

    if args.dry_run:
        print(
            f"Dry run OK: would send {manifest.get('source', 'unknown')} "
            f"to {len(split_recipients(manifest.get('to')))} recipient(s): {manifest.get('subject')}"
        )
        return 0

    oauth = load_oauth_config(token_path, credentials_path)
    access_token = refresh_access_token(oauth)
    sent = send_gmail_message(message, access_token)
    print(f"Gmail sent: id={sent.get('id', '')} threadId={sent.get('threadId', '')}")
    manifest = stamp_delivery_metadata(manifest, manifest_path, sent)
    mark_sent(manifest, manifest_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
