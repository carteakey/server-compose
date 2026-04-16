---
name: scan-services
description: Discover new self-hosted services to add to server-compose. Scans curated sources (awesome-selfhosted, optionally r/selfhosted) for candidates, filters against what's already tracked, and optionally scaffolds a new service entry (directory + docker-compose.yml + services.yaml row). Use when the user asks to "find new services", "scan for new apps", "suggest self-hosted tools", "what should I add to server-compose", or runs /scan-services.
---

# scan-services

Discover self-hosted services worth adding to this repo. Curation is the job — Claude picks a small shortlist that fits the user's existing taste; the shell helper does the mechanical work.

## Inputs

Accept optional argument hints from the user:
- **Category focus** — e.g. "networking", "monitoring", "finance". Bias the scan toward that category.
- **Source** — default is awesome-selfhosted; user may ask to scan r/selfhosted or GitHub trending.
- **Count** — how many candidates to surface (default: 5).

If the user gives no hints, scan broadly and return a balanced shortlist across categories they already use.

## Workflow

### 1. Enumerate what's already tracked

```bash
./scan-services.sh list         # one service name per line
./scan-services.sh categories   # bold categories from README table
```

Read these into memory so you can filter candidates and understand the user's taste (what kinds of services they pick, what categories dominate).

### 2. Fetch candidate sources

Use WebFetch. Default source:

- `https://raw.githubusercontent.com/awesome-selfhosted/awesome-selfhosted/master/README.md`

Optional secondary sources (use only if the user asks or the primary yields nothing useful):

- `https://www.reddit.com/r/selfhosted/top.json?t=month&limit=50` — top posts from the last month (look for "I made X" / "X just released" patterns).
- `https://github.com/trending?since=weekly&spoken_language_code=en` — weekly trending repos; filter for self-hostable patterns (dockerfile, compose in README).

When WebFetching a large markdown list, prompt the fetch with something specific — e.g. ask it to extract entries under a given category, or entries matching specific keywords the user cares about. Do not try to ingest the whole awesome-selfhosted list.

### 3. Filter against tracked services

For each candidate, run:

```bash
./scan-services.sh exists "<name>"
```

Exit 0 = already tracked (skip). Exit 1 = new (keep). This handles fuzzy matches (case, punctuation, substrings) so "Plex" correctly matches the existing `plexmediaserver` directory.

### 4. Rank the survivors

For each survivor with a GitHub repo, fetch its star count:

```bash
./scan-services.sh stars <owner/repo>
```

Rank by a mix of: stars (popularity signal), category fit (does the user already run similar tools?), and whether the upstream publishes a docker-compose.yml (lowers friction to add).

Deprioritize:
- Abandoned repos (no commits in 12+ months — check `git log` via GitHub API if in doubt)
- Services with no Docker support
- Duplicates of things the user already runs (e.g. don't suggest another dashboard if they run Homepage + Homarr)

### 5. Present the shortlist

Output format — one block per candidate, no more than 5 candidates unless the user asked for more:

```
**<Name>** — <category>
<One-sentence description>
Repo: <owner/repo> (<stars>★)
Compose: <yes/no, path if yes>
Why it fits: <one sentence tying it to what they already run>
```

End with: "Want me to scaffold any of these? I can run `./scan-services.sh scaffold <name> <repo> <compose_path>` to pull the compose file and add a services.yaml entry."

### 6. Scaffold on request

Only if the user approves a specific candidate:

```bash
./scan-services.sh scaffold <name> <owner/repo> <compose_path> [branch]
```

This creates `<name>/docker-compose.yml`, tries common branch names if the default fails, and appends a `services.yaml` entry.

**If the scaffold fails** (upstream doesn't publish a compose file): fall back to hand-rolling a minimal compose from the project's README/docs (image, ports, volumes). In that case, skip the `services.yaml` entry — there's nothing to track — and note this to the user. Follow the existing repo style: `restart: unless-stopped`, `./data` bind mount, port mapped as `"host:container"`.

After scaffolding:

1. Read the new compose file and summarize what the user will need to customize (volumes, env vars, ports).
2. Run `./check-ports.sh` (or `grep` the host port across existing compose files — `check-ports.sh` currently requires bash 4+ which macOS lacks).
3. **Insert a README table row.** Read the applications table in `README.md` to find the right category:
   - If a matching category exists, add a row with an empty first cell (`|                    |`), matching the existing indent/alignment.
   - If no category fits, add a new `**Category**` row in a logical spot (adjacent to related categories — e.g. Notes near Books/RSS, NVR near Home Automation).
   - Row format: `| **Category** | [Name](homepage-url) | One-sentence description. | [GitHub](repo-url) | [Compose](<dir>) |`
   - Match the style of nearby rows (description length, whether GitHub link is present, etc.).
4. Verify with `git diff README.md` that the table still renders (columns aligned, no broken pipes).

## Guardrails

- **Do not scaffold without explicit approval.** Scanning is cheap; creating directories and editing services.yaml is not. Always present the shortlist first.
- **Do not suggest more than ~5 candidates** unless asked. This is a curation task, not a dump.
- **Do not WebFetch the entire awesome-selfhosted list in one go.** It's huge. Fetch with a focused prompt (category or keyword) so the response stays small.
- **Respect the repo's style.** Compose files use 2-space indent, services.yaml groups by category with `# ── Name ──` dividers, the README table has 4 columns after the category. Match existing conventions when scaffolding and editing the table.
- **Check for nested duplicates.** `./scan-services.sh exists` now greps service keys inside existing compose files. Still, if a candidate is a common add-on (e.g. an Ollama frontend, a Grafana sidecar), do a sanity grep before proposing it — some services live inside a parent stack's compose file.
