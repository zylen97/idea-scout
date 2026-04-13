# Idea Scout

Full-stack academic paper radar — automated daily scanning of 80 journals + a Flutter PWA for browsing and selecting papers on mobile.

## Architecture

```
Daily Pipelines (launchd)                    App (Flutter PWA)
━━━━━━━━━━━━━━━━━━━━━━━━━                    ━━━━━━━━━━━━━━━━

09:00  FT50 (25 journals)  ─┐
  OpenAlex + LLM translation │
                             ├→  data/*.json  →  Source switcher
09:10  CE/PM (12 journals) ─┤    git push        Browse & filter
  OpenAlex + LLM translation │    gh-pages        Select papers
                             │                    Export → /idea-mine
09:20  CNKI (43 journals)  ─┘
  CNKI RSS

Each pipeline → HTML email digest (Gmail API / SMTP)
```

**Pipelines** = data fetching + LLM translation + email delivery (in `pipeline/`).
**App** = viewer/selector for browsing papers on mobile (in `lib/`).

## Pipelines

### FT50/UTD24 (25 journals)

Top management & operations journals. Source: [OpenAlex](https://openalex.org) API.

| Tier | Journals |
|:-----|:---------|
| A (9) | MS, OR, MSOM, POM, JOM, ISR, MISQ, JSCM, DS |
| B (4) | SMJ, RP, AER, JIBS |
| C (12) | OS, AMJ, JMS, AMR, ASQ, JBV, JOM2, JBE, OBHDP, OrgStudies, JAP, HR |

### CE/PM (12 journals)

Construction engineering & project management. Source: OpenAlex API.

AEI, AIC, BAE, ECAM, IJPM, JBE2, JCEM, JME, PMJ, SS, SCS, TEM

### CNKI (43 journals)

Chinese core journals across management and engineering. Source: CNKI RSS feeds.

## App Features

- **3 Data Sources**: In-app source switcher (FT50/UTD24, CE/PM, CNKI)
- **Chinese/English Toggle**: Pre-translated titles and abstracts
- **Search & Filter**: By keyword, journal, or tier
- **Paper Selection & Export**: Select papers and export as JSON for deep analysis
- **Daily Email Digests**: Automated HTML summary emails with new papers

**Live App**: https://zylen97.github.io/idea-scout/

On mobile: open the link → browser menu → "Add to Home Screen" for app-like experience.

## How Pipelines Work

Each pipeline follows the same pattern:

1. **Acquire lock** — File lock prevents concurrent git operations
2. **Sync app state** — `git pull` to get user's paper selections
3. **Scan journals** — Fetch new papers via OpenAlex API or CNKI RSS
4. **Translate** — Batch translate titles and abstracts (50 concurrent threads)
5. **Merge & deduplicate** — Filter user-deleted papers, apply time cutoff
6. **Email digest** — Send HTML email via Gmail API (primary) or SMTP (fallback)
7. **Push to GitHub** — Commit data, deploy to `gh-pages` for the app
8. **Desktop notification** — macOS notification with paper count

## Quick Start

### App (Flutter PWA)

```bash
git clone https://github.com/zylen97/idea-scout.git
cd idea-scout
flutter pub get
flutter run -d chrome
```

### Pipeline (Daily Scanning)

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

3. **Set up daily scheduling** (macOS):
   ```bash
   bash scripts/setup.sh
   ```

4. **Test manually**:
   ```bash
   bash pipeline/ft50-daily.sh
   ```

## Customizing Journals

Journal configs are in `config/`. Each follows this format:

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

Find OpenAlex source IDs at [openalex.org](https://openalex.org).

## Directory Structure

```
idea-scout/
├── lib/                         # Flutter app source
├── web/                         # PWA configuration
├── data/                        # Paper data (JSON, auto-updated daily)
├── pipeline/                    # Scanning pipeline
│   ├── scanners/                #   OpenAlex + CNKI scanners
│   ├── email/                   #   HTML email generators
│   ├── ft50-daily.sh            #   FT50 orchestrator
│   ├── cepm-daily.sh            #   CE/PM orchestrator
│   └── cnki-daily.sh            #   CNKI orchestrator
├── config/                      # Pipeline configuration
│   ├── ft50-journals.json       #   25 FT50/UTD24 journals
│   ├── cepm-journals.json       #   12 CE/PM journals
│   ├── cnki-journals.json       #   43 CNKI journals
│   └── launchd/                 #   macOS scheduler templates
├── scripts/setup.sh             # Installation script
└── pubspec.yaml                 # Flutter dependencies
```

## License

MIT
