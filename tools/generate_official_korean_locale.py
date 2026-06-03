#!/usr/bin/env python3
"""Generate official Korean render-time locale data for the local PoB overlay.

The generated Lua module is intentionally display-only. It is built from the
official English trade2 metadata and the official Korean Daum trade2 metadata,
then loaded by Modules/Localization.lua after the normal Korean UI table.
"""

from __future__ import annotations

import argparse
import json
import re
import urllib.request
from collections import defaultdict
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "src" / "Modules" / "Localization" / "ko_official_generated.lua"

SOURCES = {
    "stats_en": "https://www.pathofexile.com/api/trade2/data/stats",
    "stats_ko": "https://poe.game.daum.net/api/trade2/data/stats",
    "static_en": "https://www.pathofexile.com/api/trade2/data/static",
    "static_ko": "https://poe.game.daum.net/api/trade2/data/static",
    "items_en": "https://www.pathofexile.com/api/trade2/data/items",
    "items_ko": "https://poe.game.daum.net/api/trade2/data/items",
}

TOKEN_RE = re.compile(r"([+-]?#)|([+-]?\d[\d,]*(?:\.\d+)?)")


def fetch_json(url: str) -> dict[str, Any]:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json",
            "User-Agent": "Codex PoB2 official Korean locale generator",
        },
    )
    with urllib.request.urlopen(request, timeout=45) as response:
        return json.loads(response.read().decode("utf-8"))


def groups_by_id(payload: dict[str, Any]) -> dict[str, dict[str, Any]]:
    return {group["id"]: group for group in payload.get("result", []) if group.get("id")}


def entries_by_id(payload: dict[str, Any], text_field: str) -> dict[str, dict[str, Any]]:
    rows: dict[str, dict[str, Any]] = {}
    for group in payload.get("result", []):
        for entry in group.get("entries", []):
            entry_id = entry.get("id")
            if not entry_id:
                continue
            rows[entry_id] = {
                "group_id": group.get("id", ""),
                "group_label": group.get("label", ""),
                "value": entry.get(text_field, ""),
            }
    return rows


def build_id_joined_terms(
    kind: str,
    en_payload: dict[str, Any],
    ko_payload: dict[str, Any],
    text_field: str,
) -> list[dict[str, str]]:
    en_rows = entries_by_id(en_payload, text_field)
    ko_rows = entries_by_id(ko_payload, text_field)
    terms: list[dict[str, str]] = []
    for key in sorted(set(en_rows) & set(ko_rows)):
        en_row = en_rows[key]
        ko_row = ko_rows[key]
        terms.append(
            {
                "kind": kind,
                "key": key,
                "group_id": en_row["group_id"],
                "en": en_row["value"],
                "ko": ko_row["value"],
            }
        )
    return terms


def build_item_terms(en_payload: dict[str, Any], ko_payload: dict[str, Any]) -> list[dict[str, str]]:
    ko_groups = groups_by_id(ko_payload)
    terms: list[dict[str, str]] = []
    for en_group in en_payload.get("result", []):
        group_id = en_group.get("id", "")
        ko_group = ko_groups.get(group_id)
        if not group_id or not ko_group:
            continue
        en_entries = en_group.get("entries", [])
        ko_entries = ko_group.get("entries", [])
        for index, en_entry in enumerate(en_entries):
            if index >= len(ko_entries):
                continue
            en = en_entry.get("type", "")
            ko = ko_entries[index].get("type", "")
            if not en or not ko:
                continue
            terms.append(
                {
                    "kind": "item",
                    "key": f"{group_id}:{index}",
                    "group_id": group_id,
                    "en": en,
                    "ko": ko,
                }
            )
    return terms


def build_terms_from_official_sources() -> tuple[list[dict[str, str]], str, dict[str, str]]:
    stats_en = fetch_json(SOURCES["stats_en"])
    stats_ko = fetch_json(SOURCES["stats_ko"])
    static_en = fetch_json(SOURCES["static_en"])
    static_ko = fetch_json(SOURCES["static_ko"])
    items_en = fetch_json(SOURCES["items_en"])
    items_ko = fetch_json(SOURCES["items_ko"])

    terms: list[dict[str, str]] = []
    terms.extend(build_id_joined_terms("stat", stats_en, stats_ko, "text"))
    terms.extend(build_id_joined_terms("static", static_en, static_ko, "text"))
    terms.extend(build_item_terms(items_en, items_ko))
    terms.sort(key=lambda row: (row["kind"], row["group_id"], row["key"], row["en"]))
    return terms, datetime.now(timezone.utc).isoformat(), SOURCES


def build_terms_from_locale_json(path: Path) -> tuple[list[dict[str, str]], str, dict[str, str]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    terms = [
        {
            "kind": str(row.get("kind", "")),
            "key": str(row.get("key", "")),
            "group_id": str(row.get("group_id", "")),
            "en": str(row.get("en", "")),
            "ko": str(row.get("ko", "")),
        }
        for row in payload.get("terms", [])
    ]
    terms.sort(key=lambda row: (row["kind"], row["group_id"], row["key"], row["en"]))
    return terms, str(payload.get("generated_at") or datetime.now(timezone.utc).isoformat()), payload.get("sources", SOURCES)


def lua_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def normalize_literal_number(token: str) -> str:
    cleaned = token.replace(",", "").lstrip("+")
    try:
        value = Decimal(cleaned)
    except InvalidOperation:
        return cleaned
    return format(value.normalize(), "f")


def build_numeric_record(en: str, ko: str) -> tuple[str, tuple[int, ...], tuple[tuple[int, str], ...]] | None:
    if "#" not in en:
        return None
    if en.count("#") != ko.count("#"):
        return None

    pieces: list[str] = []
    values: list[int] = []
    literals: dict[int, str] = {}
    last_end = 0
    numeric_index = 0

    for match in TOKEN_RE.finditer(en):
        token = match.group(0)
        pieces.append(en[last_end : match.start()])
        pieces.append("#")
        last_end = match.end()
        numeric_index += 1
        if token.endswith("#"):
            values.append(numeric_index)
        else:
            literals[numeric_index] = normalize_literal_number(token)

    pieces.append(en[last_end:])
    if not values:
        return None
    return "".join(pieces), tuple(values), tuple(sorted(literals.items()))


def build_locale_tables(terms: list[dict[str, str]]) -> tuple[dict[str, str], dict[str, list[dict[str, Any]]], dict[str, int]]:
    exact: dict[str, str] = {}
    exact_conflicts: set[str] = set()
    numeric_candidates: dict[str, dict[tuple[tuple[int, ...], tuple[tuple[int, str], ...]], str | None]] = defaultdict(dict)
    skipped = {
        "same_text": 0,
        "conflict_exact": 0,
        "conflict_numeric": 0,
        "placeholder_mismatch": 0,
    }

    for row in terms:
        en = row["en"].strip()
        ko = row["ko"].strip()
        if not en or not ko:
            continue
        if en == ko:
            skipped["same_text"] += 1
            continue

        numeric_record = build_numeric_record(en, ko)
        if "#" in en and numeric_record is None:
            skipped["placeholder_mismatch"] += 1
            continue

        if numeric_record:
            key, values, literals = numeric_record
            signature = (values, literals)
            existing = numeric_candidates[key].get(signature)
            if existing is None and signature in numeric_candidates[key]:
                continue
            if existing and existing != ko:
                numeric_candidates[key][signature] = None
                skipped["conflict_numeric"] += 1
            else:
                numeric_candidates[key][signature] = ko
            continue

        if en in exact_conflicts:
            continue
        if en in exact and exact[en] != ko:
            exact.pop(en, None)
            exact_conflicts.add(en)
            skipped["conflict_exact"] += 1
        else:
            exact[en] = ko

    numeric: dict[str, list[dict[str, Any]]] = {}
    for key, entries in numeric_candidates.items():
        clean_entries: list[dict[str, Any]] = []
        for (values, literals), replace in entries.items():
            if replace is None:
                continue
            entry: dict[str, Any] = {
                "replace": replace,
                "values": list(values),
            }
            if literals:
                entry["literals"] = dict(literals)
            clean_entries.append(entry)
        if clean_entries:
            clean_entries.sort(key=lambda entry: (len(entry.get("literals", {})), entry["replace"]))
            numeric[key] = clean_entries

    return exact, numeric, skipped


def lua_values(values: list[int]) -> str:
    return "{ " + ", ".join(str(value) for value in values) + " }"


def lua_literals(literals: dict[int, str]) -> str:
    parts = [f"[{index}] = {lua_string(value)}" for index, value in sorted(literals.items())]
    return "{ " + ", ".join(parts) + " }"


def write_lua(
    output: Path,
    exact: dict[str, str],
    numeric: dict[str, list[dict[str, Any]]],
    terms: list[dict[str, str]],
    generated_at: str,
    sources: dict[str, str],
    skipped: dict[str, int],
) -> None:
    counts_by_kind = {
        "stat": sum(1 for row in terms if row["kind"] == "stat"),
        "static": sum(1 for row in terms if row["kind"] == "static"),
        "item": sum(1 for row in terms if row["kind"] == "item"),
    }

    lines: list[str] = [
        "-- Generated by tools/generate_official_korean_locale.py.",
        "-- Source: official English trade2 metadata joined with official Korean Daum trade2 metadata.",
        "-- Do not edit by hand; regenerate after PoB or game/trade metadata updates.",
        "",
        "return {",
        "\tmetadata = {",
        f"\t\tgeneratedAt = {lua_string(generated_at)},",
        f"\t\ttermCount = {len(terms)},",
        f"\t\texactCount = {len(exact)},",
        f"\t\tnumericKeyCount = {len(numeric)},",
        "\t\tcountsByKind = {",
    ]
    for kind in ("stat", "static", "item"):
        lines.append(f"\t\t\t{kind} = {counts_by_kind[kind]},")
    lines.extend(
        [
            "\t\t},",
            "\t\tskipped = {",
        ]
    )
    for key in sorted(skipped):
        lines.append(f"\t\t\t{key} = {skipped[key]},")
    lines.extend(
        [
            "\t\t},",
            "\t\tsources = {",
        ]
    )
    for key in sorted(sources):
        lines.append(f"\t\t\t{key} = {lua_string(sources[key])},")
    lines.extend(
        [
            "\t\t},",
            "\t},",
            "\texact = {",
        ]
    )

    for source in sorted(exact):
        lines.append(f"\t\t[{lua_string(source)}] = {lua_string(exact[source])},")
    lines.extend(
        [
            "\t},",
            "\tnumeric = {",
        ]
    )

    for source in sorted(numeric):
        lines.append(f"\t\t[{lua_string(source)}] = {{")
        for entry in numeric[source]:
            parts = [
                f"replace = {lua_string(entry['replace'])}",
                f"values = {lua_values(entry['values'])}",
            ]
            if entry.get("literals"):
                parts.append(f"literals = {lua_literals(entry['literals'])}")
            lines.append("\t\t\t{ " + ", ".join(parts) + " },")
        lines.append("\t\t},")

    lines.extend(["\t},", "}", ""])
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines), encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument(
        "--locale-json",
        type=Path,
        help="Use an existing official locale_terms.json table instead of fetching live trade2 metadata.",
    )
    args = parser.parse_args()

    if args.locale_json:
        terms, generated_at, sources = build_terms_from_locale_json(args.locale_json)
    else:
        terms, generated_at, sources = build_terms_from_official_sources()

    exact, numeric, skipped = build_locale_tables(terms)
    write_lua(args.output, exact, numeric, terms, generated_at, sources, skipped)
    print(
        f"Wrote {args.output} with {len(exact)} exact entries and "
        f"{sum(len(entries) for entries in numeric.values())} numeric entries "
        f"from {len(terms)} official terms."
    )


if __name__ == "__main__":
    main()
