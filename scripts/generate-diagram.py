#!/usr/bin/env python3
"""
Generate a D2 architecture diagram from a docker-compose registry.
Automatically scans directories, parses compose files, categorizes stacks
(by parsing README.md tables or using a config file), and resolves icons.
"""

from __future__ import annotations

import argparse
import json
import re
import os
import subprocess
from pathlib import Path
from typing import Any

# Try to import yaml, but provide a friendly error if missing
try:
    import yaml
except ImportError:
    yaml = None  # type: ignore


# --- Default Icon Provider Configuration ---
ICON_BASES = {
    "di": "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/main/svg",
    "dipng": "https://cdn.jsdelivr.net/gh/homarr-labs/dashboard-icons/png",
    "sh": "https://raw.githubusercontent.com/selfhst/icons/main/svg",
    "si": "https://cdn.simpleicons.org",
}

# Standard mapping of service names or images to icons
DEFAULT_SERVICE_ICONS = {
    "actual": "${di}/actual-budget.svg",
    "actual-budget": "${di}/actual-budget.svg",
    "actual-server": "${di}/actual-budget.svg",
    "adguard": "${di}/adguard-home.svg",
    "adguard-home": "${di}/adguard-home.svg",
    "adguardhome": "${di}/adguard-home.svg",
    "audiobookshelf": "${di}/audiobookshelf.svg",
    "authentik": "${di}/authentik.svg",
    "bazarr": "${di}/bazarr.svg",
    "beszel": "${di}/beszel.svg",
    "beszel-agent": "${di}/beszel.svg",
    "cadvisor": "${dipng}/cadvisor.png",
    "calibre": "${di}/calibre.svg",
    "calibre-web": "${di}/calibre-web.svg",
    "calibre-web-automated": "${di}/calibre-web.svg",
    "changedetection": "${di}/changedetection.svg",
    "changedetection.io": "${di}/changedetection.svg",
    "cloudflare-tunnel": "${di}/cloudflare.svg",
    "cloudflared": "${di}/cloudflare.svg",
    "copyparty": "${sh}/copyparty.svg",
    "deemix": "${dipng}/deemix.png",
    "dockge": "${di}/dockge.svg",
    "epicgames-freegames": "${di}/epic-games.svg",
    "filebrowser": "${di}/filebrowser.svg",
    "fileflows": "${di}/fileflows.svg",
    "firefly": "${di}/firefly-iii.svg",
    "firefly-iii": "${di}/firefly-iii.svg",
    "flaresolverr": "${di}/flaresolverr.svg",
    "freshrss": "${di}/freshrss.svg",
    "gitea": "${di}/gitea.svg",
    "grafana": "${di}/grafana.svg",
    "home-assistant": "${di}/home-assistant.svg",
    "homeassistant": "${di}/home-assistant.svg",
    "homepage": "${di}/homarr.svg",
    "homarr": "${di}/homarr.svg",
    "honeygain": "${dipng}/honeygain.png",
    "immich": "${di}/immich.svg",
    "it-tools": "${di}/it-tools.svg",
    "ittools": "${di}/it-tools.svg",
    "jellyfin": "${di}/jellyfin.svg",
    "kavita": "${di}/kavita.svg",
    "kiwix": "${di}/kiwix.svg",
    "lidarr": "${di}/lidarr.svg",
    "lidarr-on-steroids": "${di}/lidarr.svg",
    "linkding": "${di}/linkding.svg",
    "mealie": "${di}/mealie.svg",
    "memos": "${di}/memos.svg",
    "n8n": "${di}/n8n.svg",
    "navidrome": "${di}/navidrome.svg",
    "nextcloud": "${di}/nextcloud.svg",
    "node-exporter": "${di}/prometheus.svg",
    "node_exporter": "${di}/prometheus.svg",
    "ntfy": "${di}/ntfy.svg",
    "ollama": "${di}/ollama.svg",
    "open-webui": "${di}/open-webui.svg",
    "openwebui": "${di}/open-webui.svg",
    "overseerr": "${di}/overseerr.svg",
    "paperless": "${di}/paperless-ngx.svg",
    "paperless-ngx": "${di}/paperless-ngx.svg",
    "photoprism": "${di}/photoprism.svg",
    "pihole": "${di}/pi-hole.svg",
    "pi-hole": "${di}/pi-hole.svg",
    "pinchflat": "${dipng}/pinchflat.png",
    "plex": "${di}/plex.svg",
    "plexmediaserver": "${di}/plex.svg",
    "portainer": "${di}/portainer.svg",
    "profilarr": "${di}/profilarr.svg",
    "prometheus": "${di}/prometheus.svg",
    "prowlarr": "${di}/prowlarr.svg",
    "pyload": "${di}/pyload.svg",
    "qbittorrent": "${di}/qbittorrent.svg",
    "radarr": "${di}/radarr.svg",
    "readarr": "${di}/readarr.svg",
    "redis": "${di}/redis.svg",
    "scrutiny": "${di}/scrutiny.svg",
    "searxng": "${di}/searxng.svg",
    "seerr": "${di}/overseerr.svg",
    "sonarr": "${di}/sonarr.svg",
    "speedtest-tracker": "${dipng}/speedtest-tracker.png",
    "stash": "${di}/stash.svg",
    "stirling-pdf": "${di}/stirling-pdf.svg",
    "tandoor": "${dipng}/tandoor-recipes.png",
    "traefik": "${di}/traefik.svg",
    "transmission": "${di}/transmission.svg",
    "transmission-openvpn": "${di}/transmission.svg",
    "tubearchivist": "${dipng}/tube-archivist.png",
    "uptime-kuma": "${di}/uptime-kuma.svg",
    "uptime_kuma": "${di}/uptime-kuma.svg",
    "upsnap": "${di}/upsnap.svg",
    "vaultwarden": "${di}/vaultwarden.svg",
    "watchtower": "${di}/watchtower.svg",
    "windmill": "${di}/windmill.svg",
}


def d2_quote(value: str) -> str:
    """Escapes and quotes values for D2 diagram labels."""
    escaped = value.replace("\\", "\\\\").replace('"', '\\"').replace("$", "\\$").replace("\n", "\\n")
    return f'"{escaped}"'


def d2_id(value: str) -> str:
    """Generates a safe and valid D2 node identifier from a string."""
    ident = re.sub(r"[^a-zA-Z0-9_]+", "_", value.lower()).strip("_")
    if not ident:
        ident = "node"
    if ident[0].isdigit():
        ident = f"n_{ident}"
    return ident


def normalize_ports(raw_ports: Any) -> list[str]:
    """Extracts published host ports from Docker Compose port specifications."""
    if not raw_ports:
        return []
    ports: list[str] = []
    for item in raw_ports:
        if isinstance(item, str):
            # Matches formats like "8080:80", "127.0.0.1:8080:80", "80/tcp", "8080:80/udp"
            parts = item.split(":")
            if len(parts) >= 2:
                published = parts[-2]
                # Filter out IP address or empty
                if "/" in published:
                    published = published.split("/")[0]
                ports.append(published)
            else:
                # Direct port exposure e.g. "80"
                if "/" in item:
                    item = item.split("/")[0]
                ports.append(item)
        elif isinstance(item, int):
            ports.append(str(item))
        elif isinstance(item, dict):
            published = item.get("published") or item.get("target")
            if published:
                ports.append(str(published))
    return sorted(list(set(ports)))


def parse_yaml_file(path: Path) -> dict[str, Any]:
    """Parses a YAML file safely, using PyYAML if available, or fallback basic parser."""
    if not path.exists():
        return {}
    
    if yaml is not None:
        try:
            with open(path, "r", encoding="utf-8") as f:
                return yaml.safe_load(f) or {}
        except Exception as e:
            print(f"Warning: Failed to parse YAML file {path} with PyYAML: {e}")
            return {}
            
    # Basic fallback parser if PyYAML is missing (handles basic compose properties)
    content = path.read_text(encoding="utf-8")
    data: dict[str, Any] = {"services": {}}
    current_service = None
    in_services = False
    
    for line in content.splitlines():
        if line.strip().startswith("#") or not line.strip():
            continue
        
        # Check services block
        if line.startswith("services:"):
            in_services = True
            continue
        elif in_services and line and not line.startswith(" ") and not line.startswith("\t"):
            in_services = False
            
        if in_services:
            # Match service name (indented by 2 spaces)
            service_match = re.match(r"^ {2}([a-zA-Z0-9_\-]+):", line)
            if service_match:
                current_service = service_match.group(1)
                data["services"][current_service] = {"ports": [], "image": None}
                continue
                
            if current_service:
                # Match image (indented by 4 spaces)
                image_match = re.match(r"^ {4}image:\s*(.*)", line)
                if image_match:
                    data["services"][current_service]["image"] = image_match.group(1).strip("'\"")
                    continue
                # Match simple port lines
                port_line_match = re.match(r"^ {4}ports:\s*\[(.*)\]", line)
                if port_line_match:
                    ports_str = port_line_match.group(1)
                    ports = [p.strip("'\" ") for p in ports_str.split(",") if p.strip()]
                    data["services"][current_service]["ports"].extend(ports)
                # Match list ports
                if re.match(r"^ {4}ports:", line):
                    continue
                port_item_match = re.match(r"^ {6}-\s*['\"]?([0-9a-zA-Z\.\-:]+)['\"]?", line)
                if port_item_match:
                    data["services"][current_service]["ports"].append(port_item_match.group(1))
                    
    return data


def parse_readme_categories(readme_path: Path) -> dict[str, str]:
    """
    Parses README.md containing markdown tables to map subdirectory names to Categories.
    Matches tables with 'Category' and 'Docker Compose Link' columns.
    """
    if not readme_path.exists():
        return {}

    mapping: dict[str, str] = {}
    content = readme_path.read_text(encoding="utf-8")
    
    current_category = "Other"
    
    # Simple markdown table parser
    table_started = False
    headers: list[str] = []
    
    for line in content.splitlines():
        line = line.strip()
        if line.startswith("|") and line.endswith("|"):
            cells = [c.strip() for c in line.split("|")[1:-1]]
            
            # Header check
            if not table_started:
                if any("category" in str(c).lower() for c in cells) and any("compose" in str(c).lower() for c in cells):
                    table_started = True
                    headers = [c.lower() for c in cells]
                    continue
                continue
                
            # Divider line check
            if all(re.match(r"^:?\-+:?$", c) for c in cells):
                continue
                
            # Parse table rows
            if table_started and len(cells) == len(headers):
                row_dict = dict(zip(headers, cells))
                
                # Retrieve category (use previous category if empty)
                cat_val = row_dict.get("category", "").replace("**", "").replace("*", "").strip()
                if cat_val:
                    current_category = cat_val
                
                # Retrieve compose link or directory name
                # E.g. [Compose](homepage) or [Compose](homepage/docker-compose.yml)
                compose_val = ""
                for k, v in row_dict.items():
                    if "compose" in k:
                        compose_val = v
                        break
                
                if compose_val:
                    # Extract target path inside brackets/parentheses
                    match = re.search(r"\[.*?\]\((.*?)\)", compose_val)
                    if match:
                        link_path = match.group(1)
                        # Extract the folder name
                        folder = link_path.strip("/").split("/")[0]
                        if folder:
                            mapping[folder] = current_category
        else:
            table_started = False
            
    return mapping


def get_image_name(image: str | None) -> str:
    """Extracts a simple image name without registry or tags."""
    if not image:
        return ""
    # E.g. ghcr.io/hotio/jellyfin:latest -> jellyfin
    return image.split("@", 1)[0].split(":", 1)[0].split("/")[-1].lower()


def get_service_icon(service_name: str, image: str | None, custom_icons: dict[str, str]) -> str | None:
    """Resolves an icon URL for a service based on its name or image."""
    candidates = [service_name.lower(), get_image_name(image)]
    
    # Check custom config icons first
    for candidate in candidates:
        if candidate in custom_icons:
            return custom_icons[candidate]
            
    # Check default dictionary
    for candidate in candidates:
        if candidate in DEFAULT_SERVICE_ICONS:
            return DEFAULT_SERVICE_ICONS[candidate]
            
    # Fuzzy match
    for candidate in candidates:
        for key, icon in DEFAULT_SERVICE_ICONS.items():
            if key and key in candidate:
                return icon
                
    return None


def discover_services(root_path: Path, ignored_dirs: list[str]) -> list[dict[str, Any]]:
    """Scans all subdirectories for docker compose files and parses their services."""
    services_list: list[dict[str, Any]] = []
    
    for item in root_path.iterdir():
        if not item.is_dir() or item.name in ignored_dirs or item.name.startswith("."):
            continue
            
        # Check for docker-compose files in this directory
        compose_file = None
        for filename in ["docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"]:
            candidate = item / filename
            if candidate.exists():
                compose_file = candidate
                break
                
        if not compose_file:
            continue
            
        # Parse docker-compose file
        try:
            compose_data = parse_yaml_file(compose_file)
            services = compose_data.get("services") or {}
            if not isinstance(services, dict):
                continue
                
            stack_services = []
            for svc_name, svc_config in sorted(services.items()):
                if not isinstance(svc_config, dict):
                    svc_config = {}
                
                ports = normalize_ports(svc_config.get("ports") or [])
                image = svc_config.get("image")
                
                stack_services.append({
                    "name": svc_name,
                    "image": image,
                    "ports": ports,
                })
                
            if stack_services:
                services_list.append({
                    "stack": item.name,
                    "file_path": str(compose_file.relative_to(root_path)),
                    "services": stack_services
                })
        except Exception as e:
            print(f"Warning: Failed to parse stack {item.name}: {e}")
            
    return services_list


def anonymize_label(label: str, anonymize: bool) -> str:
    """Optionally replaces domain names or hostnames for public sharing."""
    if not anonymize:
        return label
    # Define replacements for common patterns
    replacements = {
        "carteakey.dev": "example.com",
    }
    for old, new in replacements.items():
        label = label.replace(old, new)
    return label


def generate_d2_markup(
    stacks: list[dict[str, Any]],
    category_mapping: dict[str, str],
    config: dict[str, Any],
    anonymize: bool = False
) -> str:
    """Generates the D2 markup text based on discovered services and settings."""
    title = config.get("title", "Server Compose Overview")
    direction = config.get("direction", "down")
    custom_icons = config.get("service_icons", {})
    connections = config.get("connections", [])
    
    lines = [
        f"# Generated D2 Architecture Diagram",
        "vars: {",
        f"  di: {ICON_BASES['di']}",
        f"  dipng: {ICON_BASES['dipng']}",
        f"  sh: {ICON_BASES['sh']}",
        f"  si: {ICON_BASES['si']}",
        "}",
        "",
        f"direction: {direction}",
        "",
        f"title: {d2_quote(title)} {{",
        "  shape: text",
        "  near: top-center",
        "  style.font-size: 40",
        "  style.bold: true",
        "}",
        "",
        "classes: {",
        "  fleet: {",
        "    style.fill: \"#f8fafc\"",
        "    style.stroke: \"#64748b\"",
        "    style.stroke-width: 3",
        "    style.border-radius: 16",
        "    style.font-size: 45",
        "    style.bold: true",
        "  }",
        "  category: {",
        "    style.fill: \"#f1f5f9\"",
        "    style.stroke: \"#cbd5e1\"",
        "    style.stroke-width: 2",
        "    style.border-radius: 12",
        "    style.font-size: 40",
        "    style.bold: true",
        "  }",
        "  stack: {",
        "    style.fill: \"#ffffff\"",
        "    style.stroke: \"#cbd5e1\"",
        "    style.border-radius: 8",
        "    style.font-size: 30",
        "  }",
        "  service: {",
        "    style.fill: \"#f0f9ff\"",
        "    style.stroke: \"#0ea5e9\"",
        "    style.border-radius: 6",
        "    style.font-size: 25",
        "  }",
        "  icon: {",
        "    style.font-size: 25",
        "    style.stroke: \"transparent\"",
        "    style.fill: \"transparent\"",
        "  }",
        "}",
        "",
        "fleet: \"Services registry\" {",
        "  class: fleet",
        "  grid-columns: 3",
        ""
    ]

    # Group stacks by category
    categorized_stacks: dict[str, list[dict[str, Any]]] = {}
    for s in stacks:
        cat = category_mapping.get(s["stack"], "Other Services")
        categorized_stacks.setdefault(cat, []).append(s)
        
    # Render categories and stacks
    for cat_name, cat_stacks in sorted(categorized_stacks.items()):
        cat_id = d2_id(cat_name)
        lines.append(f"  {cat_id}: {d2_quote(cat_name)} {{")
        lines.append("    class: category")
        lines.append("    grid-columns: 2")
        lines.append("")
        
        for stack in sorted(cat_stacks, key=lambda x: x["stack"]):
            stack_id = d2_id(stack["stack"])
            lines.append(f"    {stack_id}: {d2_quote(stack['stack'])} {{")
            lines.append("      class: stack")
            
            # Decide grid size based on service count
            svc_count = len(stack["services"])
            grid_cols = 1 if svc_count <= 2 else 2
            lines.append(f"      grid-columns: {grid_cols}")
            
            used_ids: set[str] = set()
            for idx, svc in enumerate(stack["services"], start=1):
                svc_id = d2_id(svc["name"])
                if svc_id in used_ids:
                    svc_id = f"{svc_id}_{idx}"
                used_ids.add(svc_id)
                
                # Construct service label (Name + Ports)
                ports_label = f" ({', '.join(svc['ports'])})" if svc["ports"] else ""
                label_text = f"{svc['name']}{ports_label}"
                label = anonymize_label(label_text, anonymize)
                
                # Resolve icon
                icon = get_service_icon(svc["name"], svc["image"], custom_icons)
                if icon:
                    lines.extend([
                        f"      {svc_id}: {d2_quote(label)} {{",
                        "        class: icon",
                        "        shape: image",
                        "        width: 144",
                        "        height: 144",
                        f"        icon: {icon}",
                        "      }"
                    ])
                else:
                    lines.extend([
                        f"      {svc_id}: {d2_quote(label)}",
                        f"      {svc_id}.class: service"
                    ])
                    
            lines.append("    }")
            lines.append("")
            
        lines.append("  }")
        lines.append("")
        
    lines.append("}")  # Close fleet
    lines.append("")
    
    # Custom connections defined in config
    if connections:
        lines.append("# Network / Dependency Connections")
        for conn in connections:
            frm = conn.get("from")
            to = conn.get("to")
            desc = conn.get("label")
            if frm and to:
                frm_id = f"fleet.{d2_id(category_mapping.get(frm, 'Other Services'))}.{d2_id(frm)}"
                to_id = f"fleet.{d2_id(category_mapping.get(to, 'Other Services'))}.{d2_id(to)}"
                desc_part = f": {d2_quote(desc)}" if desc else ""
                lines.append(f"{frm_id} -> {to_id}{desc_part}")
        lines.append("")
        
    return "\n".join(lines)


def compile_d2(d2_file: Path, out_format: str = "svg") -> bool:
    """Compiles a .d2 file to .svg or .png if d2 is installed."""
    out_file = d2_file.with_suffix(f".{out_format}")
    try:
        # Check if d2 is installed
        subprocess.run(["d2", "--version"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("Warning: 'd2' command-line tool not found. Skipping compilation.")
        return False
        
    print(f"Compiling {d2_file.name} to {out_file.name} using D2...")
    try:
        cmd = [
            "d2",
            "--layout", "elk",
            "--pad", "40",
            str(d2_file),
            str(out_file)
        ]
        subprocess.run(cmd, check=True)
        print(f"Successfully compiled {out_file}")
        return True
    except subprocess.CalledProcessError as e:
        print(f"Error compiling D2 file: {e}")
        return False


def main() -> int:
    parser = argparse.ArgumentParser(description="Generic docker-compose D2 Diagram Generator")
    parser.add_argument("--root", default=".", help="Root directory containing compose subdirectories")
    parser.add_argument("--out-dir", default="docs/diagrams", help="Output directory for generated diagram files")
    parser.add_argument("--config", default="diagram-config.yaml", help="Path to config file (optional)")
    parser.add_argument("--anonymize", action="store_true", help="Obfuscate domain/host names in labels")
    parser.add_argument("--compile", action="store_true", help="Compile .d2 output to SVG/PNG using 'd2' CLI")
    
    args = parser.parse_args()
    
    root_path = Path(args.root).resolve()
    out_dir = Path(root_path) / args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)
    
    # 1. Load config file
    config = {}
    config_path = root_path / args.config
    if config_path.exists():
        if yaml is not None:
            config = parse_yaml_file(config_path)
            print(f"Loaded config from {config_path}")
        else:
            print("Warning: config file specified but PyYAML is not installed. Using defaults.")
            
    # Default settings
    ignored_dirs = config.get("ignored_directories", [".git", ".github", "_assets", "scripts", "docs"])
    
    # 2. Discover compose folders
    print(f"Scanning {root_path} for docker-compose stacks...")
    discovered = discover_services(root_path, ignored_dirs)
    
    # 3. Categorize stacks
    # First priority: categories defined in config
    category_mapping = config.get("categories", {})
    
    # Second priority: parse from README.md applications table
    readme_path = root_path / "README.md"
    readme_mapping = parse_readme_categories(readme_path)
    
    # Combine (config overrides README mapping)
    combined_mapping = {**readme_mapping, **category_mapping}
    
    # 4. Generate D2 diagram markup
    d2_markup = generate_d2_markup(discovered, combined_mapping, config, anonymize=args.anonymize)
    
    # 5. Write .d2 file
    suffix = "-anon" if args.anonymize else ""
    d2_file = out_dir / f"architecture-overview{suffix}.d2"
    d2_file.write_text(d2_markup, encoding="utf-8")
    print(f"Wrote D2 source to {d2_file}")
    
    # 6. Compile if requested
    if args.compile:
        compile_d2(d2_file, "svg")
        
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
