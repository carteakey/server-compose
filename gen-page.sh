#!/usr/bin/env bash
# =============================================================================
# gen-page.sh — Generate a browseable static page (docs/index.html)
#               from the README applications table.
#
# Emits a single self-contained HTML file with inline CSS + vanilla JS for
# search and category filtering. Intended to be served via GitHub Pages
# (Settings → Pages → Branch: main, Folder: /docs).
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
README="${SCRIPT_DIR}/README.md"
OUT="${SCRIPT_DIR}/docs/index.html"
REPO_URL="https://github.com/carteakey/server-compose"

# Extract the applications table rows as JSON. Carries the category forward
# when a row starts with an empty first cell (continuation rows).
build_json() {
    awk -v repo="$REPO_URL" '
    BEGIN { in_table = 0; first = 1; print "[" }
    /^# Applications/         { in_table = 1; next }
    in_table && /^# [^#]/     { in_table = 0 }
    !in_table                 { next }

    # Skip the markdown table header + separator + blanks
    /^\| *Category/           { next }
    /^\|-/                    { next }   # separator rows (|---|---|...)
    /^$/                      { next }
    !/^\|/                    { next }

    {
        # Split on | and trim each field
        n = split($0, f, /\|/)
        # fields: f[2]=category, f[3]=name, f[4]=desc, f[5]=github, f[6]=compose
        for (i = 1; i <= n; i++) {
            gsub(/^ +| +$/, "", f[i])
        }

        cat = f[2]
        gsub(/\*\*/, "", cat)
        gsub(/<[^>]+>/, "", cat)
        if (cat != "") last_cat = cat

        # Extract name + homepage URL from f[3] (format: [Name](url) with optional anchor prefix)
        name = f[3]
        gsub(/<a id="[^"]*"><\/a>/, "", name)
        homepage = ""
        if (match(name, /\[[^]]+\]\([^)]+\)/)) {
            entry = substr(name, RSTART, RLENGTH)
            match(entry, /\[[^]]+\]/); label = substr(entry, RSTART+1, RLENGTH-2)
            match(entry, /\([^)]+\)/); homepage = substr(entry, RSTART+1, RLENGTH-2)
            name = label
        }

        desc = f[4]

        # GitHub URL
        github = ""
        if (match(f[5], /\([^)]+\)/)) github = substr(f[5], RSTART+1, RLENGTH-2)

        # Compose dir
        compose = ""
        if (match(f[6], /\([^)]+\)/)) compose = substr(f[6], RSTART+1, RLENGTH-2)

        # Skip malformed rows
        if (name == "" || last_cat == "") next

        # Escape " and \ for JSON
        gsub(/\\/, "\\\\", name); gsub(/"/, "\\\"", name)
        gsub(/\\/, "\\\\", desc); gsub(/"/, "\\\"", desc)
        gsub(/\\/, "\\\\", last_cat); gsub(/"/, "\\\"", last_cat)

        if (!first) print ","
        first = 0
        printf "  {\"category\":\"%s\",\"name\":\"%s\",\"description\":\"%s\",\"homepage\":\"%s\",\"github\":\"%s\",\"compose\":\"%s\"}",
               last_cat, name, desc, homepage, github, compose
    }
    END { print "\n]" }
    ' "$README"
}

SERVICES_JSON=$(build_json)
COUNT=$(echo "$SERVICES_JSON" | grep -c '"name"')
GENERATED=$(date -u '+%Y-%m-%d %H:%M UTC')

cat > "$OUT" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>server-compose — self-hosted service catalog</title>
<style>
  :root {
    --bg: #0f1115;
    --card: #181b22;
    --border: #262a33;
    --text: #e5e7eb;
    --muted: #8b93a7;
    --accent: #7aa2f7;
    --accent-dim: #3d59a1;
    --radius: 8px;
  }
  @media (prefers-color-scheme: light) {
    :root {
      --bg: #fafafa; --card: #ffffff; --border: #e5e7eb;
      --text: #111827; --muted: #6b7280;
      --accent: #2563eb; --accent-dim: #dbeafe;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0; padding: 2rem 1.5rem; background: var(--bg); color: var(--text);
    font: 15px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  }
  header { max-width: 1100px; margin: 0 auto 2rem; }
  h1 { font-size: 1.75rem; margin: 0 0 .25rem; }
  .sub { color: var(--muted); font-size: .9rem; }
  .sub a { color: var(--accent); text-decoration: none; }
  main { max-width: 1100px; margin: 0 auto; }
  .controls {
    position: sticky; top: 0; background: var(--bg); padding: .75rem 0;
    margin-bottom: 1rem; z-index: 10;
  }
  #search {
    width: 100%; padding: .6rem .9rem; font-size: 1rem;
    background: var(--card); border: 1px solid var(--border);
    color: var(--text); border-radius: var(--radius); outline: none;
  }
  #search:focus { border-color: var(--accent); }
  .chips { display: flex; flex-wrap: wrap; gap: .4rem; margin-top: .75rem; }
  .chip {
    padding: .3rem .7rem; font-size: .8rem; cursor: pointer;
    background: var(--card); border: 1px solid var(--border);
    color: var(--muted); border-radius: 999px; user-select: none;
  }
  .chip:hover { color: var(--text); }
  .chip.active {
    background: var(--accent-dim); border-color: var(--accent); color: var(--accent);
  }
  .grid {
    display: grid; gap: .75rem;
    grid-template-columns: repeat(auto-fill, minmax(280px, 1fr));
  }
  .card {
    background: var(--card); border: 1px solid var(--border);
    border-radius: var(--radius); padding: 1rem; display: flex;
    flex-direction: column; gap: .4rem;
  }
  .card-head { display: flex; justify-content: space-between; align-items: baseline; gap: .5rem; }
  .name { font-weight: 600; font-size: 1rem; }
  .name a { color: var(--text); text-decoration: none; }
  .name a:hover { color: var(--accent); }
  .cat { font-size: .7rem; color: var(--muted); text-transform: uppercase; letter-spacing: .05em; white-space: nowrap; }
  .desc { color: var(--muted); font-size: .88rem; flex: 1; }
  .links { display: flex; gap: .75rem; margin-top: .25rem; font-size: .82rem; }
  .links a { color: var(--accent); text-decoration: none; }
  .links a:hover { text-decoration: underline; }
  .empty { color: var(--muted); text-align: center; padding: 3rem 0; }
  footer { max-width: 1100px; margin: 3rem auto 0; color: var(--muted); font-size: .8rem; text-align: center; }
</style>
</head>
<body>
<header>
  <h1>server-compose</h1>
  <p class="sub">
    ${COUNT} self-hosted services with ready-to-use Docker Compose files.
    <a href="${REPO_URL}">View on GitHub →</a>
  </p>
</header>
<main>
  <div class="controls">
    <input id="search" type="search" placeholder="Search ${COUNT} services..." autofocus>
    <div id="chips" class="chips"></div>
  </div>
  <div id="grid" class="grid"></div>
  <div id="empty" class="empty" hidden>No services match your filter.</div>
</main>
<footer>Generated ${GENERATED} · <a href="${REPO_URL}">github.com/carteakey/server-compose</a></footer>
<script>
const SERVICES = ${SERVICES_JSON};
const REPO = "${REPO_URL}";

const grid = document.getElementById("grid");
const chips = document.getElementById("chips");
const search = document.getElementById("search");
const empty = document.getElementById("empty");

let activeCategory = "All";

const categories = ["All", ...Array.from(new Set(SERVICES.map(s => s.category))).sort()];
for (const cat of categories) {
  const el = document.createElement("span");
  el.className = "chip" + (cat === "All" ? " active" : "");
  el.textContent = cat;
  el.onclick = () => {
    activeCategory = cat;
    document.querySelectorAll(".chip").forEach(c => c.classList.toggle("active", c.textContent === cat));
    render();
  };
  chips.appendChild(el);
}

function render() {
  const q = search.value.trim().toLowerCase();
  const filtered = SERVICES.filter(s => {
    if (activeCategory !== "All" && s.category !== activeCategory) return false;
    if (!q) return true;
    return s.name.toLowerCase().includes(q) || s.description.toLowerCase().includes(q);
  });

  grid.innerHTML = "";
  empty.hidden = filtered.length > 0;

  for (const s of filtered) {
    const card = document.createElement("div");
    card.className = "card";
    const nameLink = s.homepage ? \`<a href="\${s.homepage}" target="_blank" rel="noopener">\${s.name}</a>\` : s.name;
    const links = [];
    if (s.github)  links.push(\`<a href="\${s.github}" target="_blank" rel="noopener">GitHub</a>\`);
    if (s.compose) links.push(\`<a href="\${REPO}/tree/main/\${s.compose}" target="_blank" rel="noopener">Compose</a>\`);
    card.innerHTML = \`
      <div class="card-head"><span class="name">\${nameLink}</span><span class="cat">\${s.category}</span></div>
      <div class="desc">\${s.description}</div>
      <div class="links">\${links.join("")}</div>
    \`;
    grid.appendChild(card);
  }
}

search.addEventListener("input", render);
render();
</script>
</body>
</html>
HTML

echo "✔ generated ${OUT} (${COUNT} services)"
