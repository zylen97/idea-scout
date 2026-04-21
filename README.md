# Idea Scout

Personal academic paper radar — automated daily scanning of 80 journals + a static-HTML web workbench for browsing and curating papers across devices.

**Live App**: https://zylen97.github.io/idea-scout/

## Architecture

```
Daily Pipelines (launchd)               Web Workbench (single index.html)
━━━━━━━━━━━━━━━━━━━━━━━━━              ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
                                                  ┌─────────────┐
09:00  FT50 (25 journals)  ─┐                     │ Browser     │
  OpenAlex + LLM translation │                    │  · fetch    │
                             ├→ data/*.json   ←──→│    data/*   │
09:10  CE/PM (12 journals) ─┤    git push         │  · PUT      │
  OpenAlex + LLM translation │    gh-pages        │   user_state│
                             │                    │   via PAT   │
09:20  CNKI (43 journals)  ─┘                     └─────────────┘

Each pipeline → HTML email digest (Gmail API / SMTP)
```

- **Pipelines** (in `pipeline/`) = data fetching + LLM translation + email delivery
- **Frontend** (`index.html` at repo root) = single static HTML file, no build step
- **Sync** = the page reads `data/*.json` and writes user state back via the GitHub Contents API (last-write-wins across devices)

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
- **Cross-device sync** — paste a GitHub PAT once (⚙ icon), every action debounce-syncs to `data/user_state.json` (1.5s)
- **Lifetime stats** — monthly stacked bar chart of review activity
- **Mobile** — sidebar collapses into drawer, preview into bottom sheet

## How Pipelines Work

Each pipeline follows the same pattern:

1. **Acquire lock** — File lock prevents concurrent git operations
2. **Sync state** — `git pull` to get user's curated selections from other devices
3. **Scan journals** — Fetch new papers via OpenAlex API or CNKI RSS
4. **Translate** — Batch translate titles and abstracts (50 concurrent threads)
5. **Merge & deduplicate** — Filter user-deleted papers, apply time cutoff
6. **Email digest** — Send HTML email via Gmail API (primary) or SMTP (fallback)
7. **Push to GitHub** — Commit data to main + deploy `data/*.json` to `gh-pages` (HTML stays put)
8. **Desktop notification** — macOS notification with paper count

## Quick Start

### Use the app

Open https://zylen97.github.io/idea-scout/ on any device. To enable cross-device sync of your curated lists:

1. On GitHub, create a fine-grained PAT scoped to this repo with **Contents: Read and write**
2. Click ⚙ in the top-right of the page → paste the PAT → Save
3. Done. The footer should turn green (`synced`)

### Run the pipeline locally

1. **Configure credentials**:
   ```bash
   cp config/env.example config/local.sh
   # Edit config/local.sh — set EMAIL_CONFIG_PATH
   ```

2. **Create email-config.sh** at the path you specified:
   ```bash
   SMTP_SERVER=smtp.gmail.com
   SMTP_PORT=465
   SMTP_USER=your-email@gmail.com
   SMTP_PASS=your-gmail-app-password
   EMAIL_TO=recipient@example.com
   CHATANYWHERE_API_KEY=your-chatanywhere-api-key
   ```

3. **Set up daily scheduling** (macOS launchd):
   ```bash
   bash scripts/setup.sh
   ```

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
│   ├── email/                  #   HTML email generators
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

The `gh-pages` branch holds only what GitHub Pages needs to serve: `index.html`, `data/*.json`, `favicon.png`, and a kill-switch `flutter_service_worker.js` left over from the legacy Flutter PWA (intentionally retained — uninstalls itself in returning users' browsers).

## License

MIT
