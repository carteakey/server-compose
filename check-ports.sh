#!/usr/bin/env bash
# =============================================================================
# check-ports.sh — Detect and resolve port conflicts across compose files
# =============================================================================

# This script uses associative arrays (bash 4+). macOS ships bash 3.2, so
# transparently re-exec under a newer bash if one is on PATH.
if (( BASH_VERSINFO[0] < 4 )); then
    for alt in /opt/homebrew/bin/bash /usr/local/bin/bash "$(command -v bash)"; do
        if [[ -x "$alt" ]] && "$alt" -c '(( BASH_VERSINFO[0] >= 4 ))' 2>/dev/null; then
            exec "$alt" "$0" "$@"
        fi
    done
    echo "check-ports.sh requires bash 4+ (found ${BASH_VERSION})." >&2
    echo "Install on macOS with: brew install bash" >&2
    exit 1
fi

set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIX=false

# ── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()    { echo -e "${CYAN}ℹ${NC}  $*"; }
success() { echo -e "${GREEN}✔${NC}  $*"; }
warn()    { echo -e "${YELLOW}⚠${NC}  $*"; }
error()   { echo -e "${RED}✖${NC}  $*"; }
header()  { echo -e "\n${BOLD}${CYAN}═══ $* ═══${NC}"; }

DELIM=$'\x1F'  # Unit separator — safe delimiter for joining entries

# ── Usage ────────────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
${BOLD}check-ports.sh${NC} — Detect port conflicts across compose files

${BOLD}USAGE${NC}
    ./check-ports.sh [OPTIONS]

${BOLD}OPTIONS${NC}
    --fix       Auto-resolve conflicts by reassigning duplicate host ports
    --help      Show this help message

${BOLD}EXAMPLES${NC}
    ./check-ports.sh            # Report conflicts only
    ./check-ports.sh --fix      # Report + auto-fix by reassigning ports
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix)  FIX=true; shift ;;
        --help|-h) usage ;;
        *) error "Unknown option: $1"; usage ;;
    esac
done

# ── Port Extraction ──────────────────────────────────────────────────────────

declare -A PORT_MAP       # key -> "svc|file|line<DELIM>svc|file|line..."
declare -A CONFLICTS      # key -> 1 if conflicting
declare -a ALL_PORTS=()   # ordered list of "host_port|protocol|service|file|line"

extract_ports() {
    local compose_file="$1"
    local service_dir
    service_dir=$(dirname "$compose_file" | sed "s|${SCRIPT_DIR}/||")

    local in_ports=false
    local line_num=0

    while IFS= read -r line; do
        line_num=$((line_num + 1))

        # Detect ports: section
        if [[ "$line" =~ ^[[:space:]]+ports:[[:space:]]*$ ]] || [[ "$line" =~ ^[[:space:]]+ports:$ ]]; then
            in_ports=true
            continue
        fi

        # If we're in a ports block, look for port mappings
        if $in_ports; then
            # Exit ports block when we hit a non-list, non-blank, non-comment line
            if [[ ! "$line" =~ ^[[:space:]]*- ]] && [[ ! "$line" =~ ^[[:space:]]*# ]] && [[ -n "${line// /}" ]]; then
                in_ports=false
                continue
            fi

            # Match port mappings: - "host:container" or - host:container
            if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*[\"\']?([0-9.:]+):([0-9]+)(/[a-z]+)?[\"\']? ]]; then
                local host_part="${BASH_REMATCH[1]}"
                local container_port="${BASH_REMATCH[2]}"
                local protocol="${BASH_REMATCH[3]:-/tcp}"

                # Extract just the port number (strip IP binding like 127.0.0.1:)
                local host_port
                if [[ "$host_part" =~ :?([0-9]+)$ ]]; then
                    host_port="${BASH_REMATCH[1]}"
                else
                    host_port="$host_part"
                fi

                local key="${host_port}${protocol}"
                local entry="${service_dir}|${compose_file}|${line_num}"

                ALL_PORTS+=("${host_port}|${protocol}|${service_dir}|${compose_file}|${line_num}")

                if [[ -n "${PORT_MAP[$key]:-}" ]]; then
                    PORT_MAP[$key]="${PORT_MAP[$key]}${DELIM}${entry}"
                    CONFLICTS[$key]=1
                else
                    PORT_MAP[$key]="$entry"
                fi
            fi
        fi
    done < "$compose_file"
}

# ── Main ─────────────────────────────────────────────────────────────────────

header "Port Conflict Checker"

# Find and process all compose files
compose_files=()
while IFS= read -r f; do
    compose_files+=("$f")
done < <(find "$SCRIPT_DIR" -maxdepth 2 -name 'docker-compose*.yml' -o -name 'compose.yaml' | sort)

info "Scanning ${BOLD}${#compose_files[@]}${NC} compose files...\n"

for f in "${compose_files[@]}"; do
    extract_ports "$f"
done

# ── Report ───────────────────────────────────────────────────────────────────

# Collect all unique host ports
declare -A SEEN_PORTS
for entry in "${ALL_PORTS[@]}"; do
    IFS='|' read -r host_port protocol service file line <<< "$entry"
    SEEN_PORTS[$host_port]=1
done

total_ports=${#SEEN_PORTS[@]}

if [[ ${#CONFLICTS[@]} -eq 0 ]]; then
    success "No port conflicts found across ${total_ports} unique ports"
    echo ""
    exit 0
fi

conflict_count=${#CONFLICTS[@]}
if [[ $conflict_count -eq 0 ]]; then
    # Should not reach here, but just in case
    success "No port conflicts found"
    exit 0
fi
warn "${BOLD}${conflict_count}${NC} port conflict(s) found:\n"

# Print conflict details
for key in $(echo "${!CONFLICTS[@]}" | tr ' ' '\n' | sort -t/ -k1 -n); do
    port="${key%%/*}"
    proto="${key#*/}"
    echo -e "  ${RED}${BOLD}Port ${port}/${proto}${NC} is used by:"

    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        IFS='|' read -r svc file line <<< "$entry"
        echo -e "    ${DIM}→${NC} ${CYAN}${svc}${NC}  ${DIM}(line ${line})${NC}"
    done <<< "${PORT_MAP[$key]//$DELIM/$'\n'}"
    echo ""
done

# ── Summary Table ────────────────────────────────────────────────────────────

header "Full Port Map"
echo ""
printf "  ${BOLD}%-6s %-24s %s${NC}\n" "PORT" "SERVICE" "STATUS"
printf "  ${DIM}%-6s %-24s %s${NC}\n" "──────" "────────────────────────" "──────"

for entry in $(printf '%s\n' "${ALL_PORTS[@]}" | sort -t'|' -k1 -n); do
    IFS='|' read -r host_port protocol service file line <<< "$entry"
    key="${host_port}${protocol}"
    if [[ ${#CONFLICTS[@]} -gt 0 ]] && [[ -n "${CONFLICTS[$key]:-}" ]]; then
        printf "  ${RED}%-6s${NC} %-24s ${RED}%s${NC}\n" "$host_port" "$service" "CONFLICT"
    else
        printf "  ${GREEN}%-6s${NC} %-24s ${GREEN}%s${NC}\n" "$host_port" "$service" "ok"
    fi
done

echo ""

# ── Auto-Fix ─────────────────────────────────────────────────────────────────

if ! $FIX; then
    info "Run with ${BOLD}--fix${NC} to auto-resolve conflicts"
    exit 1
fi

header "Auto-Resolving Conflicts"
echo ""

# Collect all used ports
declare -A USED_PORTS
for entry in "${ALL_PORTS[@]}"; do
    IFS='|' read -r host_port protocol service file line <<< "$entry"
    USED_PORTS[$host_port]=1
done

find_free_port() {
    local start_port="$1"
    local port=$((start_port + 1))
    while [[ -n "${USED_PORTS[$port]:-}" ]]; do
        port=$((port + 1))
    done
    echo "$port"
}

fixes_applied=0

for key in $(echo "${!CONFLICTS[@]}" | tr ' ' '\n' | sort -t/ -k1 -n); do
    port="${key%%/*}"

    first=true
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue

        IFS='|' read -r svc file line <<< "$entry"

        if $first; then
            first=false
            info "${CYAN}${svc}${NC} keeps port ${BOLD}${port}${NC}"
            continue
        fi

        new_port=$(find_free_port "$port")
        USED_PORTS[$new_port]=1

        # Use sed to replace only on the specific line
        sed -i "${line}s/${port}:/${new_port}:/" "$file"

        success "${CYAN}${svc}${NC} port ${RED}${port}${NC} → ${GREEN}${new_port}${NC}  ${DIM}(${file##*/}:${line})${NC}"
        fixes_applied=$((fixes_applied + 1))
    done <<< "${PORT_MAP[$key]//$DELIM/$'\n'}"
done

echo ""
success "${BOLD}${fixes_applied}${NC} port(s) reassigned"
info "Review the changes, then commit when satisfied"
