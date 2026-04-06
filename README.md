# Idea Scout

Scan 28 FT50/UTD24 top journals for the latest research papers, with Chinese translation support. Built for researchers seeking cross-disciplinary idea migration.

## Features

- **28 Top Journals**: Covering FT50 and UTD24 lists across Management, Operations, IS, Strategy, Economics, and more
- **3-Tier Classification**: Journals ranked by relevance to engineering management research
- **OpenAlex Integration**: Free, open academic metadata API for paper discovery
- **Chinese Translation**: Batch translate titles and abstracts via OpenAI-compatible API
- **Search & Filter**: By keyword, journal, or tier
- **Paper Selection & Export**: Select interesting papers and export as formatted text
- **Offline Cache**: Previously fetched papers are cached locally

## Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x+)

### Run locally

```bash
flutter pub get
flutter run -d chrome
```

### Build for web

```bash
flutter build web --release
```

The output will be in `build/web/`.

## Configuration

1. Open the app → Settings (gear icon)
2. Enter your OpenAI-compatible API key for translation
3. Default base URL: `https://api.chatanywhere.tech/v1`
4. Default model: `gpt-4o-mini`

Any OpenAI-compatible endpoint works (OpenAI, Azure, local LLM, etc.)

## Data Source

Paper metadata is fetched from [OpenAlex](https://openalex.org/), a free and open index of the world's research. No API key required.

## Journal List

| Tier | Journals |
|:-----|:---------|
| T1 (7) | MS, OR, MSOM, POM, JOM, ISR, MISQ |
| T2 (11) | SMJ, OS, AMJ, RP, JMS, JSCM, JBE, AER, ECMA, JIBS, MKS |
| T3 (10) | AMR, ASQ, DS, JBV, ETP, JOM2, OBHDP, OrgStudies, JAP, HR |

## License

MIT
