# Project-Scoped Rules for Server-Compose

This file contains rules and guidelines learned during development to prevent compatibility and visual regression errors in this project.

## 1. Shell Script Compatibility (macOS / BSD)
* **Bash Versions**: Avoid Bash 4+ features (like `mapfile` or associative arrays `declare -A`) in root automation scripts (like `update-compose.sh` or `check-ports.sh`). macOS ships with Bash 3.2 by default.
  * *Correction*: Use standard `while read` loops and indexed arrays.
* **Sed Regexes**: Do not use `\s` for whitespace in `sed` scripts, as the BSD-derived `sed` on macOS treats it as a literal 's'.
  * *Correction*: Use POSIX standard character classes `[[:space:]]`.

## 2. D2 Architecture Diagram Proportions
* **Scale Constraints**: When writing D2 diagrams with many nested groups (such as categories and stacks), D2 will scale text and icon nodes down significantly.
  * *Correction*: Maintain larger default font and node sizes to preserve readability:
    * `fleet` font-size: `45`
    * `category` font-size: `40`
    * `stack` font-size: `30`
    * `service`/`icon` font-size: `25`
    * Icon node dimensions: `width: 144`, `height: 144`
* **Icons Cache & Bundle**: Only map to upstream assets that exist in both SVG and PNG format. If a service does not have an icon in Homarr dashboard-icons or Simple Icons, omit the `shape: image` entirely and let it render as a standard styled box node to prevent D2 bundling/compilation 404 errors.
