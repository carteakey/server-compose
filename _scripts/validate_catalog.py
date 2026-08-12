#!/usr/bin/env python3
"""Validate the server-compose catalog without pulling or starting anything.

The manifest is intentionally explicit: a new Compose example must be added to
``catalog-validation.yaml`` before it can enter the public catalog.  Compose
files are copied to a temporary directory so explicit ``env_file`` references
are replaced with harmless example values instead of reading a developer's
working-tree secrets.  The only Docker operation performed is ``config
--quiet``.
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any, Dict, Iterable, List, Mapping, Optional, Sequence, Tuple


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "catalog-validation.yaml"
COMPOSE_FILENAMES = {"docker-compose.yml", "docker-compose.yaml", "compose.yml", "compose.yaml"}
SHELL_FILENAMES = {".sh"}
VARIABLE_RE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)[^}]*\}|\$([A-Za-z_][A-Za-z0-9_]*)")
COMPOSE_VAR_RE = re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(?::[-+?][^}]*)?\}|\$([A-Za-z_][A-Za-z0-9_]*)")

SAFE_ENV: Dict[str, str] = {
    "UPLOAD_LOCATION": "./example-upload",
    "DB_DATA_LOCATION": "./example-db-data",
    "DB_PASSWORD": "example-db-password",
    "DB_USERNAME": "example-db-user",
    "DB_DATABASE_NAME": "example-db",
    "DATABASE_URL": "postgres://postgres:example-password@db:5432/windmill",
    "WM_IMAGE": "ghcr.io/windmill-labs/windmill:latest",
    "LD_CONTAINER_NAME": "linkding-example",
    "LD_HOST_PORT": "19090",
    "LD_HOST_DATA_DIR": "./example-linkding-data",
    "POSTGRES_PASSWORD": "example-postgres-password",
    "POSTGRES_USER": "example-postgres-user",
    "POSTGRES_DB": "example-postgres-db",
    "TZ": "UTC",
    "HOSTNAME": "example-host",
}


class ValidationFailure(Exception):
    """A user-actionable validation error."""


def relpath(root: Path, path: Path) -> str:
    """Return a stable POSIX path relative to *root*."""

    return path.resolve().relative_to(root.resolve()).as_posix()


def path_is_under(path: str, root: str) -> bool:
    return path == root or path.startswith(root.rstrip("/") + "/")


def load_yaml(path: Path) -> Any:
    """Load YAML with duplicate mapping keys rejected."""

    try:
        import yaml  # type: ignore
    except ImportError as exc:  # pragma: no cover - exercised in CI setup errors
        raise ValidationFailure(
            "PyYAML is required to validate catalog YAML; install it with `python3 -m pip install pyyaml`."
        ) from exc

    class UniqueKeyLoader(yaml.SafeLoader):
        pass

    def construct_mapping(loader: Any, node: Any, deep: bool = False) -> Dict[Any, Any]:
        mapping: Dict[Any, Any] = {}
        loader.flatten_mapping(node)
        for key_node, value_node in node.value:
            key = loader.construct_object(key_node, deep=deep)
            if key in mapping:
                raise yaml.YAMLError(f"duplicate key {key!r}")
            mapping[key] = loader.construct_object(value_node, deep=deep)
        return mapping

    UniqueKeyLoader.add_constructor(  # type: ignore[arg-type]
        yaml.resolver.BaseResolver.DEFAULT_MAPPING_TAG, construct_mapping
    )
    try:
        with path.open("r", encoding="utf-8") as handle:
            return yaml.load(handle, Loader=UniqueKeyLoader)
    except (OSError, yaml.YAMLError) as exc:
        raise ValidationFailure(f"{path}: YAML parse failed: {exc}") from exc


def as_mapping(value: Any, label: str) -> Mapping[str, Any]:
    if not isinstance(value, Mapping):
        raise ValidationFailure(f"{label}: expected a YAML mapping")
    return value


def as_string_list(value: Any, label: str) -> List[str]:
    if not isinstance(value, list) or not all(isinstance(item, str) for item in value):
        raise ValidationFailure(f"{label}: expected a list of strings")
    return list(value)


def inventory_paths(manifest: Mapping[str, Any]) -> Tuple[List[str], Dict[str, Dict[str, str]]]:
    compose = as_mapping(manifest.get("compose"), "compose")
    strict = as_string_list(compose.get("strict"), "compose.strict")
    expected = compose.get("expected_failures")
    if not isinstance(expected, list):
        raise ValidationFailure("compose.expected_failures: expected a list")

    expected_by_path: Dict[str, Dict[str, str]] = {}
    for index, item in enumerate(expected):
        entry = as_mapping(item, f"compose.expected_failures[{index}]")
        path = entry.get("path")
        match = entry.get("match")
        reason = entry.get("reason")
        if not all(isinstance(value, str) and value for value in (path, match, reason)):
            raise ValidationFailure(
                f"compose.expected_failures[{index}]: path, match, and reason are required strings"
            )
        expected_by_path[path] = {"match": match, "reason": reason}

    if len(expected_by_path) != len(expected):
        raise ValidationFailure("compose.expected_failures: duplicate path")
    overlap = set(strict) & set(expected_by_path)
    if overlap:
        raise ValidationFailure(f"compose inventory lists paths in both strict and expected_failure: {sorted(overlap)}")
    if len(set(strict)) != len(strict):
        raise ValidationFailure("compose.strict: duplicate path")
    declared = strict + sorted(expected_by_path)
    return declared, expected_by_path


def excluded_roots(manifest: Mapping[str, Any]) -> List[str]:
    inventory = as_mapping(manifest.get("inventory"), "inventory")
    roots = as_string_list(inventory.get("excluded_roots"), "inventory.excluded_roots")
    if len(set(roots)) != len(roots):
        raise ValidationFailure("inventory.excluded_roots: duplicate root")
    return roots


def discover_compose_files(root: Path, excludes: Sequence[str]) -> List[str]:
    discovered: List[str] = []
    for candidate in root.rglob("*"):
        if not candidate.is_file() or candidate.name not in COMPOSE_FILENAMES:
            continue
        path = relpath(root, candidate)
        if any(path_is_under(path, excluded.rstrip("/")) for excluded in excludes):
            continue
        discovered.append(path)
    return sorted(discovered)


def discover_root_shell_scripts(root: Path) -> List[str]:
    return sorted(path.name for path in root.iterdir() if path.is_file() and path.suffix in SHELL_FILENAMES)


def validate_inventory(root: Path, manifest: Mapping[str, Any]) -> Tuple[List[str], Dict[str, Dict[str, str]], List[str]]:
    if manifest.get("schema_version") != 1:
        raise ValidationFailure("catalog-validation.yaml: schema_version must be 1")

    declared, expected = inventory_paths(manifest)
    excludes = excluded_roots(manifest)
    discovered = discover_compose_files(root, excludes)
    declared_set = set(declared)
    discovered_set = set(discovered)
    missing = sorted(declared_set - discovered_set)
    unlisted = sorted(discovered_set - declared_set)
    errors: List[str] = []
    if missing:
        errors.append(f"inventory missing Compose files: {', '.join(missing)}")
    if unlisted:
        errors.append(f"Compose files not in canonical inventory: {', '.join(unlisted)}")

    inventory = as_mapping(manifest.get("inventory"), "inventory")
    archived = as_string_list(inventory.get("archived_roots"), "inventory.archived_roots")
    for archive_root in archived:
        if not (root / archive_root).is_dir():
            errors.append(f"inventory archived root does not exist: {archive_root}")
        archived_files = [path for path in discover_compose_files(root, []) if path_is_under(path, archive_root)]
        included_archived = sorted(set(archived_files) & declared_set)
        if included_archived:
            errors.append(f"archived Compose files must not be active inventory entries: {', '.join(included_archived)}")

    generated = as_string_list(inventory.get("generated_paths"), "inventory.generated_paths")
    for path in generated:
        if not (root / path).exists():
            errors.append(f"generated catalog path does not exist: {path}")
        if path in declared_set:
            errors.append(f"generated path must not be active inventory entry: {path}")

    if errors:
        raise ValidationFailure("; ".join(errors))
    return declared, expected, errors


def compose_variable_values(source: Path) -> Dict[str, str]:
    values = dict(SAFE_ENV)
    text = source.read_text(encoding="utf-8")
    for match in VARIABLE_RE.finditer(text):
        name = match.group(1) or match.group(2)
        expression = match.group(0)
        # Preserve Compose's safe defaults (for example `${PORT:-3002}`)
        # instead of replacing them with the generic string "example".
        if ":-" not in expression and ":+" not in expression:
            values.setdefault(name, "example")
    return values


def substitute_variables(value: str, values: Mapping[str, str]) -> str:
    def replacement(match: re.Match[str]) -> str:
        name = match.group(1) or match.group(2)
        return values.get(name, "example")

    return COMPOSE_VAR_RE.sub(replacement, value)


def env_file_values(node: Any) -> Iterable[str]:
    """Yield env_file paths from a parsed Compose document without reading them."""

    if isinstance(node, Mapping):
        for key, value in node.items():
            if key == "env_file":
                if isinstance(value, str):
                    yield value
                elif isinstance(value, list):
                    for item in value:
                        if isinstance(item, str):
                            yield item
                        elif isinstance(item, Mapping) and isinstance(item.get("path"), str):
                            yield item["path"]
                elif isinstance(value, Mapping) and isinstance(value.get("path"), str):
                    yield value["path"]
            else:
                yield from env_file_values(value)
    elif isinstance(node, list):
        for item in node:
            yield from env_file_values(item)


def copy_for_compose_validation(
    root: Path, source: Path, temp_root: Path, safe_values: Mapping[str, str]
) -> Tuple[Path, Path]:
    """Copy one Compose file and create sanitized explicit env files."""

    try:
        parsed = load_yaml(source)
    except ValidationFailure:
        raise
    destination = temp_root / relpath(root, source)
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, destination)
    for raw_ref in env_file_values(parsed):
        substituted = substitute_variables(raw_ref, safe_values)
        ref = Path(substituted)
        if ref.is_absolute() or ".." in ref.parts:
            raise ValidationFailure(
                f"{relpath(root, source)}: env_file path must stay relative for secret-free validation: {raw_ref}"
            )
        target = destination.parent / ref
        target.parent.mkdir(parents=True, exist_ok=True)
        # Deliberately never copy the source env file.  Compose only needs the
        # file to exist for syntax validation; values come from SAFE_ENV.
        target.write_text("EXAMPLE_VALUE=example\n", encoding="utf-8")

    env_file = temp_root / "catalog-validation.env"
    if not env_file.exists():
        env_file.write_text("".join(f"{key}={value}\n" for key, value in sorted(safe_values.items())), encoding="utf-8")
    return destination, env_file


def diagnostic(stdout: str, stderr: str, temp_file: Path, source: Path) -> str:
    text = (stderr.strip() or stdout.strip() or "no diagnostic output").replace(str(temp_file), str(source))
    return " | ".join(line.strip() for line in text.splitlines() if line.strip())[:1000]


def validate_compose(root: Path, paths: Sequence[str], expected: Mapping[str, Mapping[str, str]]) -> List[str]:
    errors: List[str] = []
    if shutil.which("docker") is None:
        return ["docker CLI is required for Compose config validation"]

    with tempfile.TemporaryDirectory(prefix="server-compose-catalog-") as temp_dir:
        temp_root = Path(temp_dir)
        safe_values = dict(SAFE_ENV)
        for path in paths:
            safe_values.update(compose_variable_values(root / path))
        env_file = temp_root / "catalog-validation.env"
        env_file.write_text("".join(f"{key}={value}\n" for key, value in sorted(safe_values.items())), encoding="utf-8")
        for path in paths:
            source = root / path
            try:
                temp_file, _ = copy_for_compose_validation(root, source, temp_root, safe_values)
            except ValidationFailure as exc:
                errors.append(str(exc))
                continue

            try:
                result = subprocess.run(
                    ["docker", "compose", "--env-file", str(env_file), "-f", str(temp_file), "config", "--quiet"],
                    cwd=root,
                    env={**os.environ, "COMPOSE_DISABLE_ENV_FILE": "1"},
                    capture_output=True,
                    text=True,
                    timeout=60,
                    check=False,
                )
            except subprocess.TimeoutExpired:
                errors.append(f"{path}: docker compose config --quiet timed out after 60 seconds")
                continue
            except OSError as exc:
                errors.append(f"{path}: could not run docker compose config --quiet: {exc}")
                continue

            details = diagnostic(result.stdout, result.stderr, temp_file, source)
            if path in expected:
                expected_match = expected[path]["match"]
                if result.returncode == 0:
                    errors.append(f"{path}: manifest expects an explicit parser exception, but Compose passed")
                    print(f"[compose] FAIL {path}: expected failure disappeared; review the manifest")
                elif expected_match not in details:
                    errors.append(
                        f"{path}: expected parser error containing {expected_match!r}, got: {details}"
                    )
                    print(f"[compose] FAIL {path}: unexpected parser error: {details}")
                else:
                    print(f"[compose] EXPECTED {path}: {expected[path]['reason']} ({details})")
            elif result.returncode != 0:
                errors.append(f"{path}: docker compose config --quiet failed: {details}")
                print(f"[compose] FAIL {path}: {details}")
            else:
                print(f"[compose] PASS {path}")
    return errors


def validate_shell_scripts(root: Path, manifest: Mapping[str, Any]) -> List[str]:
    scripts = as_string_list(manifest.get("shell_scripts"), "shell_scripts")
    errors: List[str] = []
    discovered = discover_root_shell_scripts(root)
    if sorted(scripts) != discovered:
        errors.append(
            "shell script inventory mismatch: "
            f"declared={sorted(scripts)!r}, discovered={discovered!r}"
        )
    if shutil.which("bash") is None:
        return errors + ["bash is required for non-mutating shell syntax checks"]
    for script in scripts:
        path = root / script
        if not path.is_file():
            errors.append(f"{script}: shell script does not exist")
            continue
        result = subprocess.run(
            ["bash", "-n", str(path)], cwd=root, capture_output=True, text=True, check=False
        )
        if result.returncode:
            details = (result.stderr.strip() or result.stdout.strip() or "syntax error").replace(str(path), script)
            errors.append(f"{script}: bash -n failed: {details}")
            print(f"[shell] FAIL {script}: {details}")
        else:
            print(f"[shell] PASS {script}")
    return errors


def safe_local_path(root: Path, service: str, compose_file: str) -> Tuple[Path, str]:
    candidate = Path(service) / compose_file
    if candidate.is_absolute() or ".." in candidate.parts:
        raise ValidationFailure(f"services.yaml service {service}: compose_file escapes repository: {compose_file}")
    path = root / candidate
    return path, candidate.as_posix()


def validate_services_catalog(root: Path, manifest: Mapping[str, Any], inventory: Sequence[str]) -> List[str]:
    catalog = as_mapping(manifest.get("catalog"), "catalog")
    services_file = catalog.get("services_file")
    readme_file = catalog.get("readme_file")
    if not isinstance(services_file, str) or not isinstance(readme_file, str):
        raise ValidationFailure("catalog.services_file and catalog.readme_file are required strings")

    errors: List[str] = []
    services_data = as_mapping(load_yaml(root / services_file), services_file)
    services = as_mapping(services_data.get("services"), f"{services_file}.services")
    required_fields = {
        "github_raw": ("repo", "path"),
        "github_release": ("repo", "asset"),
        "url": ("url",),
    }
    inventory_set = set(inventory)
    for name, value in services.items():
        if not isinstance(name, str) or not re.fullmatch(r"[a-z0-9][a-z0-9._-]*", name):
            errors.append(f"{services_file}: invalid service key {name!r}")
            continue
        entry = as_mapping(value, f"{services_file}.services.{name}")
        source_type = entry.get("source_type")
        if source_type not in required_fields:
            errors.append(f"{services_file}.services.{name}: unsupported source_type {source_type!r}")
            continue
        for field in required_fields[source_type]:
            if not isinstance(entry.get(field), str) or not entry.get(field):
                errors.append(f"{services_file}.services.{name}: missing {field}")
        compose_file = entry.get("compose_file", "docker-compose.yml")
        if not isinstance(compose_file, str):
            errors.append(f"{services_file}.services.{name}: compose_file must be a string")
            continue
        try:
            local_path, inventory_path = safe_local_path(root, name, compose_file)
        except ValidationFailure as exc:
            errors.append(str(exc))
            continue
        if not local_path.is_file():
            errors.append(f"{services_file}.services.{name}: local Compose file missing: {inventory_path}")
        elif inventory_path not in inventory_set:
            errors.append(f"{services_file}.services.{name}: {inventory_path} is not in canonical inventory")
    print(f"[catalog] PASS {services_file}: {len(services)} updater entries")

    readme = root / readme_file
    if not readme.is_file():
        errors.append(f"{readme_file}: README catalog file does not exist")
        return errors
    compose_links: List[str] = []
    for line_number, line in enumerate(readme.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.startswith("|") or "[Compose]" not in line:
            continue
        if line.count("|") < 6:
            errors.append(f"{readme_file}:{line_number}: malformed catalog table row")
        match = re.search(r"\[Compose\]\(([^)]+)\)", line)
        if not match:
            errors.append(f"{readme_file}:{line_number}: malformed Compose link")
            continue
        compose_links.append(match.group(1))
    if len(compose_links) != len(set(compose_links)):
        errors.append(f"{readme_file}: duplicate Compose catalog link")
    for link in compose_links:
        if not (root / link).is_dir():
            errors.append(f"{readme_file}: Compose link target is not a service directory: {link}")
        elif not any(path_is_under(path, link) for path in inventory_set):
            errors.append(f"{readme_file}: Compose link has no active inventory file: {link}")

    allow_raw = catalog.get("allow_unlisted_compose", [])
    if not isinstance(allow_raw, list):
        errors.append("catalog.allow_unlisted_compose: expected a list")
        allow_raw = []
    allowed_dirs: Dict[str, str] = {}
    for index, item in enumerate(allow_raw):
        entry = as_mapping(item, f"catalog.allow_unlisted_compose[{index}]")
        path = entry.get("path")
        reason = entry.get("reason")
        if not isinstance(path, str) or not isinstance(reason, str) or not reason:
            errors.append(f"catalog.allow_unlisted_compose[{index}]: path and reason are required")
            continue
        allowed_dirs[Path(path).parent.as_posix()] = reason

    inventory_dirs = {Path(path).parent.as_posix() for path in inventory_set}
    advertised_dirs = set(compose_links)
    for directory in sorted(inventory_dirs - advertised_dirs):
        if directory not in allowed_dirs:
            errors.append(f"{readme_file}: active Compose directory is not advertised: {directory}")
        else:
            print(f"[catalog] EXPECTED {directory}: {allowed_dirs[directory]}")
    print(f"[catalog] PASS {readme_file}: {len(compose_links)} Compose links")
    return errors


def run(root: Path, manifest_path: Path) -> int:
    print("Catalog validation (non-deploying; Compose config only)")
    try:
        manifest = as_mapping(load_yaml(manifest_path), str(manifest_path))
        inventory, expected, _ = validate_inventory(root, manifest)
    except ValidationFailure as exc:
        print(f"[inventory] FAIL: {exc}", file=sys.stderr)
        return 1

    print(f"[inventory] PASS: {len(inventory)} active Compose files")
    errors: List[str] = []
    errors.extend(validate_compose(root, inventory, expected))
    errors.extend(validate_shell_scripts(root, manifest))
    try:
        errors.extend(validate_services_catalog(root, manifest, inventory))
    except ValidationFailure as exc:
        errors.append(str(exc))

    if errors:
        print("\nValidation failures:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print(f"Validation passed: {len(inventory)} Compose files, shell syntax, and catalog structure")
    return 0


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT, help="repository root (default: this checkout)")
    parser.add_argument(
        "--manifest", type=Path, default=DEFAULT_MANIFEST, help="inventory manifest (default: catalog-validation.yaml)"
    )
    args = parser.parse_args(argv)
    return run(args.root.resolve(), args.manifest.resolve())


if __name__ == "__main__":
    raise SystemExit(main())
