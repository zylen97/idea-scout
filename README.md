# Idea Scout

Personal academic paper radar — automated daily scanning of 80 journals, now used as a local data pipeline for Academic OS Dashboard.

**Local Dashboard**: http://127.0.0.1:5174

## Architecture

```
Daily Pipelines (Codex Automation)      Academic OS Dashboard
━━━━━━━━━━━━━━━━━━━━━━━━━              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                  ┌─────────────┐
09:00  FT50 (25 journals)  ─┐                     │ Browser     │
  OpenAlex + LLM translation │                    │  · fetch    │
                             ├→ data/*.json   ←──→│    local API│
09:10  CE/PM (12 journals) ─┤                     │  · writes   │
  OpenAlex + LLM translation │                    │   user_state│
                             │                    │   locally   │
09:20  CNKI (43 journals)  ─┘                     └─────────────┘
09:30+ Catch-up check      ─────→ missed source? run + send

Each pipeline → HTML + JSON digest manifest → Codex Gmail plugin
```

- **Pipelines** (in `pipeline/`) = data fetching + LLM translation + digest export
- **Email delivery** = Codex Automation reads `logs/digests/*-latest.json`, sends via Codex Gmail plugin, then marks seen IDs
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

### CNKI (43 journals)
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
7. **Desktop notification** — macOS notification with paper count and optional local Dashboard open

The pipeline does not commit, push `main`, or deploy `gh-pages`.

## Codex Gmail Delivery

The shell pipeline does **not** send email directly. It exports a manifest:

```bash
logs/digests/ft50-latest.json
logs/digests/cepm-latest.json
logs/digests/cnki-latest.json
```

Codex Automation should:

1. Run the corresponding daily pipeline.
2. Read the latest manifest.
3. If `send` is `true`, read `html_path` and send it with the Codex Gmail plugin using `subject` and `to`.
4. After Gmail returns success, run `mark_sent_command` from the manifest.

This keeps `seen_dois.json` / `cnki_seen_titles.json` unchanged unless Gmail delivery actually succeeds.

### Missed-Run Catch-Up

If the Mac is asleep at the exact daily time, the catch-up automation runs a lightweight hourly check after 09:30:

```bash
python3 pipeline/catchup_status.py --grace-minutes 30
```

It reports each source as:

- `not_due` — the grace window has not opened yet
- `complete` — today's digest is already generated and sent, or no new papers were found
- `needs_run` — today's pipeline did not run yet
- `needs_send` — today's digest exists but Gmail delivery was not marked complete
- `blocked` — configuration is incomplete, for example no recipients

The catch-up automation only runs missing work. It sends via the Codex Gmail plugin and runs `mark_sent_command` only after Gmail returns success.

## Quick Start

### Use the app

Start Academic OS Dashboard and open http://127.0.0.1:5174. Idea Scout state is local-first; no GitHub PAT is needed.

### Run the pipeline locally

1. **Configure credentials**:
   ```bash
   cp config/env.example config/local.sh
   # Edit config/local.sh — set EMAIL_CONFIG_PATH
   ```

2. **Create email-config.sh** at the path you specified:
   ```bash
   EMAIL_TO=recipient@example.com
   CHATANYWHERE_API_KEY=your-chatanywhere-api-key
   ```

3. **Daily scheduling**:
   The active daily jobs live in Codex Automations, not launchd. A catch-up automation checks for missed runs after 09:30.

4. **Test manually**:
   ```bash
   bash pipeline/ft50-daily.sh
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
│   ├── email/                  #   HTML digest exporters + seen marker
│   ├── catchup_status.py       #   Missed-run detector for Codex Automation
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
