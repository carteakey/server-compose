#!/usr/bin/env bash
# =============================================================================
# update-compose.sh — Auto-pull latest compose files from upstream sources
# =============================================================================
#
# Reads services.yaml to discover upstream URLs, fetches the latest compose
# files, diffs them against local copies, and optionally backs up + replaces.
#
# Usage:
#   ./update-compose.sh                     # update all services (pull only)
#   ./update-compose.sh --service immich    # update a single service
#   ./update-compose.sh --dry-run           # show diffs without writing files
#   ./update-compose.sh --apply             # also run docker compose up -d
#   ./update-compose.sh --verbose           # show full diffs
#
# Dependencies: bash, curl, diff
# Optional:     yq (falls back to built-in parser if not installed)
# =============================================================================

set -uo pipefail

# ── Defaults ─────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_FILE="${SCRIPT_DIR}/services.yaml"
DRY_RUN=false
APPLY=false
VERBOSE=false
INTERACTIVE=false
APPROVE_ALL=false
TARGET_SERVICE=""
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# ── Colors ───────────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ── Counters ─────────────────────────────────────────────────────────────────

COUNT_UPDATED=0
COUNT_UNCHANGED=0
COUNT_FAILED=0
COUNT_SKIPPED=0

# ── Logging ──────────────────────────────────────────────────────────────────

info()    { echo -e "${BLUE}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✖${NC}  $*"; }
header()  { echo -e "\n${BOLD}${CYAN}═══ $* ═══${NC}"; }
dim()     { echo -e "${DIM}   $*${NC}"; }

# ── Usage ────────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
${BOLD}update-compose.sh${NC} — Auto-pull latest compose files from upstream

${BOLD}USAGE${NC}
    ./update-compose.sh [OPTIONS]

${BOLD}OPTIONS${NC}
    --interactive, -i       Review and approve each change interactively
    --dry-run               Show what would change without writing files
    --apply                 After updating, run 'docker compose up -d'
    --service <name>        Update only a specific service
    --verbose               Show full diffs
    --help                  Show this help message

${BOLD}EXAMPLES${NC}
    ./update-compose.sh -i                       # Interactive approval mode
    ./update-compose.sh --dry-run                # Preview changes only
    ./update-compose.sh --service immich -v      # Pull immich, show diff
    ./update-compose.sh --apply                  # Pull all + restart changed
EOF
    exit 0
}

# ── Argument Parsing ─────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)        DRY_RUN=true; shift ;;
        --apply)          APPLY=true; shift ;;
        --interactive|-i) INTERACTIVE=true; VERBOSE=true; shift ;;
        --verbose|-v)     VERBOSE=true; shift ;;
        --service|-s)     TARGET_SERVICE="$2"; shift 2 ;;
        --help|-h)        usage ;;
        *)                error "Unknown option: $1"; usage ;;
    esac
done

# ── YAML Parser ──────────────────────────────────────────────────────────────
# Minimal parser that extracts service blocks from services.yaml.
# Works without yq by parsing the YAML structure directly.

# Returns list of service names from services.yaml
get_service_names() {
    grep -E '^  [a-zA-Z0-9]' "$SERVICES_FILE" \
        | grep -v '^[[:space:]]*#' \
        | sed 's/^[[:space:]]*//' \
        | sed 's/:.*//' \
        | sort
}

# Get a property value for a given service
# Usage: get_service_prop <service_name> <property>
get_service_prop() {
    local service="$1"
    local prop="$2"
    local in_service=false
    local indent=""

    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// /}" ]] && continue

        # Detect service block start (exactly 2-space indent + name + colon)
        if [[ "$line" =~ ^[[:space:]]{2}[a-zA-Z0-9] ]] && [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
            local name
            name=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/:.*//')
            if [[ "$name" == "$service" ]]; then
                in_service=true
                continue
            else
                if $in_service; then
                    return 1  # Past our service block
                fi
            fi
        fi

        # Inside our service block, look for the property
        if $in_service; then
            # If we hit a line that's not indented enough, we've left the block
            if [[ "$line" =~ ^[[:space:]]{2}[a-zA-Z] ]] && [[ ! "$line" =~ ^[[:space:]]{4} ]]; then
                return 1
            fi
            if [[ "$line" =~ ^[[:space:]]+${prop}:[[:space:]]*(.*) ]]; then
                local value="${BASH_REMATCH[1]}"
                # Trim trailing whitespace and comments
                value=$(echo "$value" | sed 's/[[:space:]]*#.*//' | sed 's/[[:space:]]*$//')
                echo "$value"
                return 0
            fi
        fi
    done < "$SERVICES_FILE"

    return 1
}

# ── URL Resolvers ────────────────────────────────────────────────────────────

resolve_github_release_url() {
    local repo="$1"
    local asset="$2"

    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    local response
    response=$(curl -sS --fail -L "$api_url" 2>/dev/null) || {
        error "Failed to fetch releases for ${repo}"
        return 1
    }

    # Extract the browser_download_url for the target asset
    local download_url
    download_url=$(echo "$response" \
        | grep -o "\"browser_download_url\":[[:space:]]*\"[^\"]*${asset}\"" \
        | head -1 \
        | sed 's/.*"browser_download_url":[[:space:]]*"//' \
        | sed 's/"$//')

    if [[ -z "$download_url" ]]; then
        # Some repos attach compose files as release body links, try source tarball fallback
        error "Asset '${asset}' not found in latest release of ${repo}"
        return 1
    fi

    echo "$download_url"
}

resolve_github_raw_url() {
    local repo="$1"
    local branch="${2:-main}"
    local path="$3"

    echo "https://raw.githubusercontent.com/${repo}/${branch}/${path}"
}

# ── Core: Process a single service ───────────────────────────────────────────

process_service() {
    local service="$1"
    local service_dir="${SCRIPT_DIR}/${service}"
    local compose_file

    compose_file=$(get_service_prop "$service" "compose_file" 2>/dev/null || echo "docker-compose.yml")
    local local_file="${service_dir}/${compose_file}"

    # Resolve the download URL
    local source_type download_url
    source_type=$(get_service_prop "$service" "source_type") || {
        error "${service}: missing source_type"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        return
    }

    case "$source_type" in
        github_release)
            local repo asset
            repo=$(get_service_prop "$service" "repo") || { error "${service}: missing repo"; COUNT_FAILED=$((COUNT_FAILED + 1)); return; }
            asset=$(get_service_prop "$service" "asset") || { error "${service}: missing asset"; COUNT_FAILED=$((COUNT_FAILED + 1)); return; }
            download_url=$(resolve_github_release_url "$repo" "$asset") || { COUNT_FAILED=$((COUNT_FAILED + 1)); return; }
            ;;
        github_raw)
            local repo branch path
            repo=$(get_service_prop "$service" "repo") || { error "${service}: missing repo"; COUNT_FAILED=$((COUNT_FAILED + 1)); return; }
            branch=$(get_service_prop "$service" "branch" 2>/dev/null || echo "main")
            path=$(get_service_prop "$service" "path") || { error "${service}: missing path"; COUNT_FAILED=$((COUNT_FAILED + 1)); return; }
            download_url=$(resolve_github_raw_url "$repo" "$branch" "$path")
            ;;
        url)
            download_url=$(get_service_prop "$service" "url") || { error "${service}: missing url"; COUNT_FAILED=$((COUNT_FAILED + 1)); return; }
            ;;
        *)
            error "${service}: unknown source_type '${source_type}'"
            COUNT_FAILED=$((COUNT_FAILED + 1))
            return
            ;;
    esac

    dim "Fetching from: ${download_url}"

    # Download to temp file
    local tmp_file
    tmp_file=$(mktemp)
    trap "rm -f '$tmp_file'" RETURN

    if ! curl -sS --fail -L -o "$tmp_file" "$download_url" 2>/dev/null; then
        error "${service}: failed to download from ${download_url}"
        rm -f "$tmp_file"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        return
    fi

    # Check if downloaded file is valid (non-empty)
    if [[ ! -s "$tmp_file" ]]; then
        error "${service}: downloaded file is empty"
        rm -f "$tmp_file"
        COUNT_FAILED=$((COUNT_FAILED + 1))
        return
    fi

    # Compare with local file
    if [[ ! -f "$local_file" ]]; then
        warn "${service}: local file '${compose_file}' does not exist, creating"
        if ! $DRY_RUN; then
            mkdir -p "$service_dir"
            cp "$tmp_file" "$local_file"
        fi
        success "${service}: ${BOLD}NEW${NC} — file created"
        COUNT_UPDATED=$((COUNT_UPDATED + 1))
        rm -f "$tmp_file"
        return
    fi

    # Diff
    local diff_output
    diff_output=$(diff --unified=3 "$local_file" "$tmp_file" 2>/dev/null || true)

    if [[ -z "$diff_output" ]]; then
        success "${service}: up to date"
        COUNT_UNCHANGED=$((COUNT_UNCHANGED + 1))
        rm -f "$tmp_file"
        return
    fi

    # Changes detected
    warn "${service}: ${BOLD}CHANGES DETECTED${NC}"

    if $VERBOSE; then
        echo -e "${DIM}────────────────────────────────────────${NC}"
        # Color-coded diff output
        while IFS= read -r line; do
            case "$line" in
                ---*)  echo -e "${BOLD}${RED}${line}${NC}" ;;
                +++*)  echo -e "${BOLD}${GREEN}${line}${NC}" ;;
                @@*)   echo -e "${CYAN}${line}${NC}" ;;
                +*)    echo -e "${GREEN}${line}${NC}" ;;
                -*)    echo -e "${RED}${line}${NC}" ;;
                *)     echo -e "${DIM}${line}${NC}" ;;
            esac
        done <<< "$diff_output"
        echo -e "${DIM}────────────────────────────────────────${NC}"
    else
        local additions removals
        additions=$(echo "$diff_output" | grep -c '^+[^+]' || true)
        removals=$(echo "$diff_output" | grep -c '^-[^-]' || true)
        dim "${GREEN}+${additions}${NC} ${RED}-${removals}${NC} lines changed"
    fi

    if $DRY_RUN; then
        dim "(dry-run: no files modified)"
        COUNT_UPDATED=$((COUNT_UPDATED + 1))
        rm -f "$tmp_file"
        return
    fi

    # Interactive approval
    if $INTERACTIVE && ! $APPROVE_ALL; then
        echo -e "   ${BOLD}Apply this change?${NC} [${GREEN}y${NC}]es / [${RED}n${NC}]o / [${CYAN}a${NC}]ll / [${YELLOW}q${NC}]uit"
        while true; do
            read -r -p "   > " choice
            case "${choice,,}" in
                y|yes)
                    break
                    ;;
                n|no)
                    dim "Skipped"
                    COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
                    rm -f "$tmp_file"
                    return
                    ;;
                a|all)
                    APPROVE_ALL=true
                    break
                    ;;
                q|quit)
                    info "Aborted by user"
                    rm -f "$tmp_file"
                    exit 0
                    ;;
                *)
                    echo -e "   ${DIM}Enter y, n, a, or q${NC}"
                    ;;
            esac
        done
    fi

    # Backup and replace
    cp "$local_file" "${local_file}${BACKUP_SUFFIX}"
    dim "Backup saved: ${compose_file}${BACKUP_SUFFIX}"
    cp "$tmp_file" "$local_file"
    success "${service}: updated"
    COUNT_UPDATED=$((COUNT_UPDATED + 1))

    # Optionally apply
    if $APPLY; then
        info "${service}: running 'docker compose up -d'..."
        if (cd "$service_dir" && docker compose -f "$compose_file" up -d 2>&1); then
            success "${service}: containers restarted"
        else
            error "${service}: failed to restart containers"
        fi
    fi

    rm -f "$tmp_file"
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    header "Compose File Auto-Updater"

    # Validate
    if [[ ! -f "$SERVICES_FILE" ]]; then
        error "Services file not found: ${SERVICES_FILE}"
        exit 1
    fi

    if $DRY_RUN; then
        info "Running in ${BOLD}dry-run${NC} mode — no files will be modified"
    fi

    if $INTERACTIVE; then
        info "Running in ${BOLD}interactive${NC} mode — you will approve each change"
    fi

    if $APPLY; then
        info "Running with ${BOLD}--apply${NC} — changed services will be restarted"
    fi

    echo ""

    # Get services to process
    local services
    if [[ -n "$TARGET_SERVICE" ]]; then
        # Validate the target exists in config
        if ! get_service_prop "$TARGET_SERVICE" "source_type" &>/dev/null; then
            error "Service '${TARGET_SERVICE}' not found in ${SERVICES_FILE}"
            exit 1
        fi
        services=("$TARGET_SERVICE")
    else
        services=()
        while IFS= read -r line; do
            services+=("$line")
        done < <(get_service_names)
    fi

    local total=${#services[@]}
    info "Processing ${BOLD}${total}${NC} service(s)...\n"

    local i=0
    for service in "${services[@]}"; do
        i=$((i + 1))
        echo -e "${BOLD}[${i}/${total}]${NC} ${CYAN}${service}${NC}"
        process_service "$service"
        echo ""
    done

    # Summary
    header "Summary"
    echo -e "  ${GREEN}✔ Updated:${NC}    ${COUNT_UPDATED}"
    echo -e "  ${BLUE}● Unchanged:${NC}  ${COUNT_UNCHANGED}"
    echo -e "  ${RED}✖ Failed:${NC}     ${COUNT_FAILED}"
    echo -e "  ${DIM}○ Skipped:${NC}    ${COUNT_SKIPPED}"
    echo ""

    if $DRY_RUN && [[ $COUNT_UPDATED -gt 0 ]]; then
        info "Run without ${BOLD}--dry-run${NC} to apply updates"
    fi
}

main "$@"
