#!/usr/bin/env python3
"""Print Morpho forum paste payloads + submission URLs.

Cannot authenticate to forum.morpho.org from this environment without Discourse API key.
Copies are ready in deployments/FORUM-POST-*.md — open URL and paste.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "deployments"

TARGETS = [
    (
        "Steakhouse Financial",
        "https://forum.morpho.org/c/vaults/steakhouse-financial/18",
        "https://forum.morpho.org/new-topic?category=vaults/steakhouse-financial",
        ROOT / "FORUM-POST-STEAKHOUSE.md",
    ),
    (
        "Gauntlet",
        "https://forum.morpho.org/c/vaults/gauntlet/19",
        "https://forum.morpho.org/new-topic?category=vaults/gauntlet",
        ROOT / "FORUM-POST-GAUNTLET.md",
    ),
]


def main() -> None:
    print("CURATOR FORUM SUBMIT — paste-ready\n")
    for name, cat, new_url, path in TARGETS:
        body = path.read_text()
        title = body.splitlines()[0].lstrip("# ").strip()
        print("=" * 72)
        print(f"TARGET: {name}")
        print(f"CATEGORY: {cat}")
        print(f"NEW TOPIC: {new_url}")
        print(f"FILE: {path}")
        print(f"TITLE: {title}")
        print("-" * 72)
        print(body)
        print()


if __name__ == "__main__":
    main()
