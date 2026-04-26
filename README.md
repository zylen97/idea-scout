# Idea Scout

Personal academic paper radar — automated daily scanning of 81 journals, now used as a local data pipeline for Academic OS Dashboard.

**Local Dashboard**: http://127.0.0.1:5174

## Architecture

```
Daily Pipelines (local launchd)         Academic OS Dashboard
━━━━━━━━━━━━━━━━━━━━━━━━━              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                  ┌─────────────┐
09:00  FT50 (25 journals)  ─┐                     │ Browser     │
  OpenAlex + LLM translation │                    │  · fetch    │
                             ├→ data/*.json   ←──→│    local API│
09:10  CE/PM (12 journals) ─┤                     │  · writes   │
  OpenAlex + LLM translation │                    │   user_state│
                             │                    │   locally   │
09:20  CNKI (44 journals)  ─┘                     └─────────────┘

Each pipeline → HTML + JSON digest manifest → local Gmail API → mark seen
```

- **Pipelines** (in `pipeline/`) = data fetching + LLM translation + digest export
- **Email delivery** = the same local launchd job sends `logs/digests/*-latest.json` via Gmail API, then marks seen IDs
- **Frontend** = Academic OS Dashboard reads local `data/*.json`
- **Sync** = Dashboard writes local `data/user_state.json`; GitHub token / GitHub Pages sync is retired

## Pipelines

### FT50/UTD24 (25 journals)
Top management & operations journals. Source: [OpenAlex](https://openalex.org).

| Tier | Journals |
|:-----|:---------|
| A (9) | MS, OR, MSOM, POM, JOM, ISR, MISQ, JSCM, DS |
| B (4) | SMJ, RP, AER, JIBS |
| C (12) | OS, AMJ, JMS, AMR, ASQ, JBV, JOM2, JBE, OBHDP, OrgStudies, JAP, HR |

### CE/PM (12 journals)
Construction engineering & project management. Source: OpenAlex. **Flat list — no tier ranking.**

AEI, AIC, BAE, ECAM, IJPM, JBE2, JCEM, JME, PMJ, SS, SCS, TEM

### CNKI (44 journals)
Chinese core journals. Source: CNKI RSS. Categorized as **管理A / 管理B1 / 管理B2 / 工程 / 其他**.

## Frontend Features

- **3 sources** with per-source ranking semantics (FT50 A/B/C · CE/PM flat · CNKI 5-way category)
- **Bilingual** — pre-translated EN/中 titles + abstracts, toggle in preview
- **Filter & sort** — by journal, tier/category, date range, keyword
- **Curate** — `I` to mark idea, `D` to delete, `Space` to multi-select, `E` to export RIS
- **Local sync** — Dashboard writes every curation action to local `data/user_state.json`
- **Lifetime stats** — monthly stacked bar chart of review activity
- **Mobile** — sidebar collapses into drawer, preview into bottom sheet

## How Pipelines Work

Each pipeline follows the same pattern:

1. **Acquire lock** — File lock prevents concurrent writes to `data/`
2. **Snapshot state** — copy local `data/user_state.json` so deleted / Idea papers stay filtered
3. **Scan journals** — Fetch new papers via OpenAlex API or CNKI RSS
4. **Translate** — Batch translate titles and abstracts (50 concurrent threads)
5. **Merge & deduplicate** — Filter user-deleted papers, apply time cutoff
6. **Digest export** — Write HTML body + JSON manifest to `logs/digests/`
7. **Gmail delivery** — Send through the local Gmail API OAuth token, then mark seen IDs
8. **Desktop notification** — macOS notification with paper count and optional local Dashboard open

The pipeline does not commit, push `main`, or deploy `gh-pages`.

## Local Gmail Delivery

The shell pipeline sends email directly after exporting the manifest:

```bash
logs/digests/ft50-latest.json
logs/digests/cepm-latest.json
logs/digests/cnki-latest.json
```

The local launchd job:

1. Reads the latest manifest.
2. If `send` is `true`, reads `html_path` and sends it with the Gmail API using `subject` and `to`.
3. After Gmail returns success, runs `pipeline/email/mark_sent.py`.

This keeps `seen_dois.json` / `cnki_seen_titles.json` unchanged unless Gmail delivery actually succeeds.

### Missed-Run Diagnostics

Use the lightweight check after 09:30 to verify whether launchd produced and sent today's digests:

```bash
python3 pipeline/catchup_status.py --grace-minutes 30
```

It reports each source as:

- `not_due` — the grace window has not opened yet
- `complete` — today's digest is already generated and sent, or no new papers were found
- `needs_send` — today's digest exists but Gmail delivery was not marked complete
- `blocked` — local launchd did not produce today's manifest, the scan failed, or configuration is incomplete

If a manifest is `needs_send`, run:

```bash
set -a
source config/local.sh
[ -n "$EMAIL_CONFIG_PATH" ] && source "$EMAIL_CONFIG_PATH"
set +a
python3 pipeline/email/send_manifest.py logs/digests/ft50-latest.json
```

## Quick Start

### Use the app

Start Academic OS Dashboard and open http://127.0.0.1:5174. Idea Scout state is local-first; no GitHub PAT is needed.

### Run the pipeline locally

1. **Configure credentials**:
   ```bash
   cp config/env.example config/local.sh
   # Edit config/local.sh — set EMAIL_CONFIG_PATH, GMAIL_TOKEN_PATH, GMAIL_CREDENTIALS_PATH
   ```

2. **Create email-config.sh** at the path you specified:
   ```bash
   EMAIL_TO=recipient@example.com
   CHATANYWHERE_API_KEY=your-chatanywhere-api-key
   SMTP_USER=your-gmail-address@example.com
   ```

3. **Daily scheduling**:
   ```bash
   bash scripts/setup.sh
   ```

   The active scan and Gmail jobs live in local launchd.

4. **Test manually**:
   ```bash
   bash pipeline/ft50-daily.sh
   python3 pipeline/email/send_manifest.py logs/digests/ft50-latest.json --dry-run
   ```

## Customizing Journals

Journal configs are in `config/`. FT50/CE-PM use `tier: 1|2|3`; CNKI uses `category: "管理A"|"管理B1"|"管理B2"|"工程"|"其他"`.

```json
{
  "openalex_mailto": "your-email@example.com",
  "source": "ft50",
  "journals": [
    {
      "id": "MS",
      "name": "Management Science",
      "openalex_id": "S33323087",
      "issn": "0025-1909",
      "tier": 1,
      "tags": ["game theory", "optimization"]
    }
  ]
}
```

When adding CNKI journals, also update the `CNKI_CATEGORY` map inlined at the top of `index.html`.

Find OpenAlex source IDs at [openalex.org](https://openalex.org).

## Directory Structure

```
idea-scout/
├── index.html                  # Static web workbench (single file, no build)
├── data/                       # Paper data + user_state (auto-updated daily)
├── pipeline/                   # Scanning pipelines
│   ├── scanners/               #   OpenAlex + CNKI scanners (Python)
│   ├── email/                  #   HTML digest exporters + local Gmail sender + seen marker
│   ├── catchup_status.py       #   Missed-run / send-status diagnostic
│   ├── ft50-daily.sh           #   FT50 orchestrator (09:00)
│   ├── cepm-daily.sh           #   CE/PM orchestrator (09:10)
│   └── cnki-daily.sh           #   CNKI orchestrator (09:20)
├── config/                     # Pipeline + journal configuration
│   ├── ft50-journals.json      #   25 FT50/UTD24 journals
│   ├── cepm-journals.json      #   12 CE/PM journals
│   ├── cnki-journals.json      #   43 CNKI journals
│   └── launchd/                #   macOS scheduler templates
└── scripts/setup.sh            # Installation helper
```

The legacy `gh-pages` branch and root `index.html` are kept only as historical/static assets. Daily work should go through the local Dashboard.

## License

MIT
