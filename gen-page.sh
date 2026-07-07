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
  @import url('https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@400;500;600;700&display=swap');
  
  :root {
    --bg: #0b0c10;
    --bg-gradient: linear-gradient(135deg, #0b0c10 0%, #161a24 100%);
    --card: rgba(22, 27, 37, 0.65);
    --border: rgba(255, 255, 255, 0.07);
    --text: #f3f4f6;
    --muted: #9ca3af;
    --accent: #60a5fa;
    --accent-dim: rgba(96, 165, 250, 0.12);
    --accent-text: #0b0c10;
    --radius: 12px;
  }
  @media (prefers-color-scheme: light) {
    :root {
      --bg: #f8fafc;
      --bg-gradient: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
      --card: rgba(255, 255, 255, 0.75);
      --border: rgba(0, 0, 0, 0.06);
      --text: #0f172a;
      --muted: #64748b;
      --accent: #2563eb;
      --accent-dim: rgba(37, 99, 235, 0.08);
      --accent-text: #ffffff;
    }
  }
  * { box-sizing: border-box; }
  body {
    margin: 0;
    padding: 3rem 2rem;
    background: var(--bg);
    background-image: var(--bg-gradient);
    background-attachment: fixed;
    color: var(--text);
    font-family: 'Plus Jakarta Sans', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
    min-height: 100vh;
  }
  header { max-width: 1140px; margin: 0 auto 3rem; }
  h1 { font-size: 2.25rem; font-weight: 700; margin: 0 0 .5rem; letter-spacing: -0.025em; }
  .sub { color: var(--muted); font-size: 1.05rem; font-weight: 400; }
  .sub a { color: var(--accent); text-decoration: none; font-weight: 500; transition: opacity 0.2s ease; }
  .sub a:hover { opacity: 0.85; }
  main { max-width: 1140px; margin: 0 auto; }
  .controls {
    position: sticky; top: 0; background: rgba(11, 12, 16, 0.8);
    backdrop-filter: blur(12px); -webkit-backdrop-filter: blur(12px);
    padding: 1rem 0;
    margin-bottom: 2rem; z-index: 10;
    border-bottom: 1px solid var(--border);
  }
  @media (prefers-color-scheme: light) {
    .controls { background: rgba(248, 250, 252, 0.8); }
  }
  #search {
    width: 100%; padding: .8rem 1.2rem; font-size: 1.05rem;
    background: var(--card); border: 1px solid var(--border);
    color: var(--text); border-radius: var(--radius); outline: none;
    box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05);
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }
  #search:focus {
    border-color: var(--accent);
    box-shadow: 0 0 0 4px var(--accent-dim);
  }
  .chips { display: flex; flex-wrap: wrap; gap: .5rem; margin-top: 1rem; }
  .chip {
    padding: .4rem .9rem; font-size: .8rem; font-weight: 500; cursor: pointer;
    background: var(--card); border: 1px solid var(--border);
    color: var(--muted); border-radius: 999px; user-select: none;
    transition: all 0.2s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .chip:hover { color: var(--text); border-color: var(--muted); }
  .chip.active {
    background: var(--accent); border-color: var(--accent); color: var(--accent-text);
    font-weight: 600; box-shadow: 0 4px 12px -2px var(--accent-dim);
  }
  .grid {
    display: grid; gap: 1rem;
    grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  }
  .card {
    background: var(--card); border: 1px solid var(--border);
    backdrop-filter: blur(8px); -webkit-backdrop-filter: blur(8px);
    border-radius: var(--radius); padding: 1.5rem; display: flex;
    flex-direction: column; gap: .75rem;
    box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05);
    transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  }
  .card:hover {
    transform: translateY(-4px);
    border-color: var(--accent);
    box-shadow: 0 12px 20px -5px rgba(0, 0, 0, 0.15), 0 8px 10px -6px rgba(0, 0, 0, 0.15);
  }
  .card-head { display: flex; justify-content: space-between; align-items: baseline; gap: .5rem; }
  .name { font-weight: 600; font-size: 1.1rem; letter-spacing: -0.01em; }
  .name a { color: var(--text); text-decoration: none; transition: color 0.2s ease; }
  .name a:hover { color: var(--accent); }
  .cat { font-size: .7rem; font-weight: 600; color: var(--accent); background: var(--accent-dim); padding: .2rem .5rem; border-radius: 4px; text-transform: uppercase; letter-spacing: .05em; white-space: nowrap; }
  .desc { color: var(--muted); font-size: .92rem; line-height: 1.6; flex: 1; }
  .links { display: flex; gap: 1rem; margin-top: .5rem; font-size: .85rem; }
  .links a { color: var(--accent); text-decoration: none; font-weight: 600; transition: opacity 0.2s ease; }
  .links a:hover { opacity: 0.8; text-decoration: underline; }
  .empty { color: var(--muted); text-align: center; padding: 4rem 0; font-size: 1.1rem; }
  footer { max-width: 1140px; margin: 4rem auto 0; color: var(--muted); font-size: .85rem; text-align: center; border-top: 1px solid var(--border); padding-top: 2rem; }
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

function renderChips() {
  chips.innerHTML = "";
  for (const cat of categories) {
    const count = cat === "All" ? SERVICES.length : SERVICES.filter(s => s.category === cat).length;
    const el = document.createElement("span");
    el.className = "chip" + (cat === activeCategory ? " active" : "");
    el.textContent = \`\${cat} (\${count})\`;
    el.onclick = () => {
      activeCategory = cat;
      renderChips();
      render();
    };
    chips.appendChild(el);
  }
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
    if (s.compose) links.push(\`<a href="\${REPO}/tree/main/\${s.compose}" target="_blank" rel="noopener">Compose Config</a>\`);
    card.innerHTML = \`
      <div class="card-head"><span class="name">\${nameLink}</span><span class="cat">\${s.category}</span></div>
      <div class="desc">\${s.description}</div>
      <div class="links">\${links.join("")}</div>
    \`;
    grid.appendChild(card);
  }
}

search.addEventListener("input", render);
renderChips();
render();
</script>
</body>
</html>
HTML

echo "✔ generated ${OUT} (${COUNT} services)"
