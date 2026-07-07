# Docker Compose D2 Architecture Diagram Generator

This directory contains `generate-diagram.py` — a portable, generic Python script that automatically scans your directory of Docker Compose stacks, extracts metadata (such as exposed host ports, active service names, and container images), and builds a structured, responsive architecture diagram using the [D2 diagramming language](https://d2lang.com/).

---

## Features
* **Auto-Discovery**: Recursively scans directories to discover all compose stacks and services.
* **Smart Category Mapping**: Clusters stacks into category blocks derived from either a custom YAML config file or table groupings in your main `README.md`.
* **Exposed Port Extraction**: Detects host ports and displays them directly next to service names (e.g. `homepage (3000)`).
* **Automatic Brand Icons**: Integrates with [Homarr Dashboard Icons](https://github.com/homarr-labs/dashboard-icons) and [Simple Icons](https://simpleicons.org/) to automatically load official branding icons for recognized services.
* **Obfuscation / Anonymization**: Scans labels and replaces custom domains (e.g. `yourdomain.me`) with `example.com` when compiling for public sharing.
* **CLI Compiler**: Optionally compiles `.d2` code directly into `.svg` or `.png` files via the `d2` CLI.
* **No-Dependency Fallback**: Works out-of-the-box using python standard libraries. If `PyYAML` isn't installed, it falls back to a regex parser.

---

## Quick Start

### 1. Prerequisites
To generate the raw D2 markup text, you only need Python 3. 

To render the diagram into an image (`.svg` or `.png`), install the [D2 CLI](https://d2lang.com/tour/install):
```bash
# macOS (Homebrew)
brew install d2

# Linux
curl -fsSL https://d2lang.com/install.sh | sh
```

### 2. Generate and Compile
Run the script from the root of your project:
```bash
# Output D2 markup code only (saved to docs/diagrams/)
python3 _scripts/generate-diagram.py

# Generate and compile directly to SVG/PNG (requires D2 CLI)
python3 _scripts/generate-diagram.py --compile
```

---

## Command Line Options

| Flag | Default | Description |
| :--- | :--- | :--- |
| `--root` | `.` | Directory containing your docker-compose stack folders. |
| `--out-dir` | `docs/diagrams` | Output directory where generated D2/SVG/PNG files will be saved. |
| `--config` | `diagram-config.yaml` | Path to custom settings config file (optional). |
| `--anonymize` | *None* | Obfuscate domain names (e.g. replacing custom domains with `example.com`). |
| `--compile` | *None* | Trigger D2 CLI compiler to output `.svg` and `.png` image files. |

---

## Configuration (`diagram-config.yaml`)

Create a `diagram-config.yaml` in your root folder to customize layout settings, map categories, add custom icons, and draw service relationship arrows:

```yaml
# The title displayed on the diagram
title: "Homelab Architecture Overview"

# Layout direction: down, up, left, right
direction: down

# Directories to ignore during scanning
ignored_directories:
  - ".git"
  - ".github"
  - "_assets"
  - "_scripts"
  - "docs"

# Custom Category overrides for stack folders.
# If a folder isn't listed here, the script parses categories from README.md
# (table headers) or falls back to 'Other Services'.
categories:
  actual-budget: "Finance"
  changedetection.io: "Tools"
  media-server: "Media"

# Service-specific custom icon overrides.
# Supports Homarr dashboard-icons variables (${di} for SVG, ${dipng} for PNG) 
# and Simple Icons (${si} for CDN).
service_icons:
  actual-budget: "${di}/actual-budget.svg"
  linkding: "${di}/linkding.svg"
  pi-hole: "${di}/pi-hole.svg"

# Domains to obfuscate when running --anonymize
anonymize_domains:
  - "homelab.my-internal-domain.net"
  - "router.local"

# Custom connection lines (arrows) to draw between services
# Links are resolved dynamically using service or stack names.
connections:
  - from: "sonarr"
    to: "qbittorrent"
    label: "Downloads Torrent"
  - from: "radarr"
    to: "qbittorrent"
    label: "Downloads Torrent"
```

---

## CI/CD Automation (GitHub Actions)

Add the following workflow file under `.github/workflows/render-diagrams.yaml` to automatically regenerate your architecture diagram and commit it back to your repository on every push:

```yaml
name: Generate Stacks Diagram
on:
  push:
    branches: [main]
    paths:
      - "**/docker-compose.y*ml"
      - "**/compose.y*ml"
      - "diagram-config.yaml"
      - "_scripts/generate-diagram.py"
  workflow_dispatch:

jobs:
  render:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.x"

      - name: Install dependencies
        run: pip install PyYAML

      - name: Generate D2 markup
        run: |
          python3 _scripts/generate-diagram.py --config diagram-config.yaml

      - name: Render D2 to SVG/PNG
        run: |
          # Install D2 CLI in CI environment
          curl -fsSL https://d2lang.com/install.sh | sh
          
          # Render the D2 source file
          d2 --layout=elk --pad=40 docs/diagrams/architecture-overview.d2 docs/diagrams/architecture-overview.svg

      - name: Commit and Push Changes
        run: |
          git config --global user.name "github-actions[bot]"
          git config --global user.email "github-actions[bot]@users.noreply.github.com"
          git add docs/diagrams/
          if ! git diff --staged --quiet; then
            git commit -m "chore(diagram): regenerate architecture diagrams [skip ci]"
            git push
          fi
```
