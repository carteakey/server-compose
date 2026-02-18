---
description: How to add or update docker-compose files in the server-compose repository
---

# Adding or Updating Compose Files

This workflow describes how an LLM agent should add new services or update existing compose files in the `server-compose` repository.

## Repository Structure

Each service lives in its own directory at the repo root:
```
server-compose/
├── services.yaml            # Upstream source registry
├── update-compose.sh        # Auto-pull script
├── <service-name>/
│   ├── docker-compose.yml   # Main compose file
│   ├── .env or example.env  # Optional environment variables
│   └── README.md            # Optional, links to docs
```

## Adding a New Service

### 1. Create the service directory and compose file

```bash
mkdir -p /home/kchauhan/repos/server-compose/<service-name>
```

Write a `docker-compose.yml` following these conventions:
- Use the **official image** or the **linuxserver.io image** where available
- Use `restart: unless-stopped` for all services
- Map config volumes to `./config` or named volumes
- Use placeholder values wrapped in `<angle_brackets>` for user-specific config (e.g., `<your_timezone>`, `<path_to_media>`)
- Include inline comments explaining non-obvious settings
- Pin image tags where appropriate (e.g., `image: lscr.io/linuxserver/radarr:latest`)

### 2. Add an upstream source to `services.yaml` (if available)

// turbo
Check if the upstream project publishes a standalone `docker-compose.yml` file. Verify the URL returns HTTP 200:

```bash
curl -s -o /dev/null -w "%{http_code}" "<candidate_url>"
```

If the URL works, add an entry to `services.yaml`:

```yaml
  <service-name>:
    source_type: github_raw      # or github_release or url
    repo: owner/repo
    branch: main
    path: docker-compose.yml
```

Source types:
- `github_release` — for repos that attach compose files to GitHub releases (e.g., Immich)
- `github_raw` — for repos with compose files in the tree (most common)
- `url` — for arbitrary download URLs

**Important:** Many projects (e.g., Radarr, Sonarr, Jellyfin, Grafana) do NOT publish standalone compose files. Only add an entry if you can verify the URL works. It is perfectly fine to not have an entry — the service will simply be skipped by the auto-updater.

### 3. Create a README.md (optional)

A simple README linking to the official documentation:

```markdown
# <Service Name>

<link to official Docker installation docs>
```

### 4. Verify the service entry

// turbo
If you added the service to `services.yaml`, verify it works:

```bash
./update-compose.sh --dry-run --service <service-name> --verbose
```

Expected: the script should fetch the file and show a diff (or "up to date" if files match). It should NOT show "failed to download".

## Updating an Existing Service

### Option A: Manual update

1. Edit the `docker-compose.yml` directly
2. Keep placeholder values — do not commit real secrets or paths
3. Test syntax: `docker compose -f <service>/docker-compose.yml config --quiet`

### Option B: Pull from upstream

// turbo
Run the auto-updater in interactive mode to review changes:

```bash
./update-compose.sh --interactive --service <service-name>
```

This will:
1. Fetch the latest compose file from the upstream source in `services.yaml`
2. Show the full diff
3. Prompt for approval before overwriting

To pull all services at once with approval:

```bash
./update-compose.sh --interactive
```

### Option C: Dry-run check

// turbo
To see what would change without modifying files:

```bash
./update-compose.sh --dry-run --service <service-name> --verbose
```

## Fixing a Broken Upstream URL

If a service fails to fetch during `update-compose.sh`:

1. Find the correct URL by checking:
   - The project's GitHub repo for a `docker-compose.yml` in root or `docker/` folder
   - The project's Docker documentation page
   - A separate `docker` repo under the same GitHub org (e.g., `firefly-iii/docker`)
   - The `linuxserver/docker-<name>` repo

// turbo
2. Verify the candidate URL:
```bash
curl -s -o /dev/null -w "%{http_code}" "<candidate_url>"
```

3. Update the entry in `services.yaml` with the correct URL

// turbo
4. Re-verify:
```bash
./update-compose.sh --dry-run --service <service-name> --verbose
```

## Important Rules

- **Never commit real secrets** — use `<placeholder>` values for passwords, API keys, paths
- **Preserve local customizations** — the `--interactive` flag exists so users can review upstream changes before applying. Upstream compose files may differ from the local custom config
- **Always verify URLs** — before adding to `services.yaml`, confirm the URL returns HTTP 200
- **Backup files are auto-created** — when a file is updated, a `.bak.TIMESTAMP` backup is saved alongside it. These are gitignored
