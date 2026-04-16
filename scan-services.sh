#!/usr/bin/env bash
# =============================================================================
# scan-services.sh — Helpers for the scan-services skill
# =============================================================================
#
# Mechanical operations used by the scan-services skill. The skill (Claude)
# handles curation and reasoning; this script handles deterministic work:
# enumerating existing services, checking for duplicates, and scaffolding
# a new service entry.
#
# Usage:
#   ./scan-services.sh list                       # list tracked services
#   ./scan-services.sh categories                 # list README categories
#   ./scan-services.sh exists <name>              # 0 if tracked, 1 otherwise
#   ./scan-services.sh stars <owner/repo>         # fetch GitHub star count
#   ./scan-services.sh scaffold <name> <repo> [compose_path] [branch]
#        Creates <name>/ dir, fetches compose file, adds services.yaml entry.
# =============================================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_FILE="${SCRIPT_DIR}/services.yaml"
README_FILE="${SCRIPT_DIR}/README.md"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; DIM='\033[2m'; NC='\033[0m'

err()  { echo -e "${RED}✖${NC} $*" >&2; }
ok()   { echo -e "${GREEN}✔${NC} $*" >&2; }
info() { echo -e "${BLUE}ℹ${NC} $*" >&2; }

# ── list: tracked services (directories with a compose file) ────────────────

cmd_list() {
    find "$SCRIPT_DIR" -mindepth 2 -maxdepth 2 \
        \( -name 'docker-compose.yml' -o -name 'docker-compose.yaml' \
           -o -name 'compose.yml' -o -name 'compose.yaml' \) \
        -not -path '*/_*/*' -not -path '*/.*/*' \
        2>/dev/null \
        | awk -F/ '{print $(NF-1)}' \
        | sort -u
}

# ── categories: extract README category headers from the applications table ─

cmd_categories() {
    grep -oE '\*\*[A-Z][^*]+\*\*' "$README_FILE" \
        | sed 's/\*\*//g' \
        | sort -u
}

# ── exists: fuzzy-check if a candidate is already tracked ───────────────────
# Normalizes name (lowercase, strip separators) and checks against tracked
# service names and README entries.

normalize() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d '.-_ '
}

cmd_exists() {
    local query="${1:-}"
    [[ -z "$query" ]] && { err "usage: exists <name>"; return 2; }

    local norm_q
    norm_q=$(normalize "$query")

    while IFS= read -r svc; do
        local norm_s
        norm_s=$(normalize "$svc")
        if [[ "$norm_s" == "$norm_q" ]] || [[ "$norm_s" == *"$norm_q"* ]] \
           || [[ "$norm_q" == *"$norm_s"* ]]; then
            echo "$svc"
            return 0
        fi
    done < <(cmd_list)

    # Check service keys inside existing compose files (catches services
    # nested inside a multi-service stack, e.g. open-webui inside ollama/).
    local hit
    hit=$(grep -rElE "^[[:space:]]{2}${query}:" \
            --include='docker-compose.y*ml' \
            --include='compose.y*ml' \
            "$SCRIPT_DIR" 2>/dev/null \
          | head -1)
    if [[ -n "$hit" ]]; then
        echo "(defined in $(basename "$(dirname "$hit")")/$(basename "$hit"))"
        return 0
    fi

    # Also search README for name mentions
    if grep -qiE "\[${query}[^]]*\]\(" "$README_FILE" 2>/dev/null; then
        echo "(mentioned in README)"
        return 0
    fi

    return 1
}

# ── stars: fetch GitHub star count for a repo ───────────────────────────────

cmd_stars() {
    local repo="${1:-}"
    [[ -z "$repo" ]] && { err "usage: stars <owner/repo>"; return 2; }

    local response
    response=$(curl -sS --fail -L \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/repos/${repo}" 2>/dev/null) || {
        err "failed to fetch ${repo}"
        return 1
    }

    echo "$response" | grep -oE '"stargazers_count":[[:space:]]*[0-9]+' \
        | head -1 | grep -oE '[0-9]+'
}

# ── scaffold: create a new service entry ────────────────────────────────────

cmd_scaffold() {
    local name="${1:-}"
    local repo="${2:-}"
    local path="${3:-docker-compose.yml}"
    local branch="${4:-main}"

    if [[ -z "$name" || -z "$repo" ]]; then
        err "usage: scaffold <name> <owner/repo> [compose_path] [branch]"
        return 2
    fi

    local target_dir="${SCRIPT_DIR}/${name}"

    if [[ -d "$target_dir" ]]; then
        err "directory already exists: ${name}/"
        return 1
    fi

    # Try both provided branch and common alternatives if first fails
    local url tmp
    tmp=$(mktemp)
    local fetched_branch=""
    for try_branch in "$branch" main master develop; do
        url="https://raw.githubusercontent.com/${repo}/${try_branch}/${path}"
        if curl -sS --fail -L -o "$tmp" "$url" 2>/dev/null && [[ -s "$tmp" ]]; then
            fetched_branch="$try_branch"
            break
        fi
    done

    if [[ -z "$fetched_branch" ]]; then
        err "could not fetch compose file from ${repo} (tried: ${branch}, main, master, develop)"
        rm -f "$tmp"
        return 1
    fi

    mkdir -p "$target_dir"
    mv "$tmp" "${target_dir}/docker-compose.yml"
    ok "created ${name}/docker-compose.yml (from ${repo}@${fetched_branch})"

    # Append entry to services.yaml
    cat >> "$SERVICES_FILE" <<EOF

  ${name}:
    source_type: github_raw
    repo: ${repo}
    branch: ${fetched_branch}
    path: ${path}
EOF
    ok "appended ${name} to services.yaml"

    info "next steps:"
    echo "  1. review ${name}/docker-compose.yml and adjust ports/volumes" >&2
    echo "  2. add a row to README.md applications table" >&2
    echo "  3. run: ./check-ports.sh to verify no conflicts" >&2
}

# ── main ─────────────────────────────────────────────────────────────────────

case "${1:-}" in
    list)        cmd_list ;;
    categories)  cmd_categories ;;
    exists)      shift; cmd_exists "$@" ;;
    stars)       shift; cmd_stars "$@" ;;
    scaffold)    shift; cmd_scaffold "$@" ;;
    ''|help|-h|--help)
        grep -E '^#( |$)' "$0" | sed 's/^# \{0,1\}//'
        ;;
    *)
        err "unknown command: $1"
        exit 2
        ;;
esac
