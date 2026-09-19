#!/usr/bin/env python3
"""Read and update .una_asahi_setup.json."""

from __future__ import annotations

import json
import os
import sys
import tempfile
from datetime import datetime, timezone


def _load(path: str) -> dict | None:
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


def _save(path: str, data: dict) -> None:
    directory = os.path.dirname(path) or "."
    fd, tmp_path = tempfile.mkstemp(
        dir=directory, prefix=".una_asahi_setup.", suffix=".tmp"
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=2)
            handle.write("\n")
        os.replace(tmp_path, path)
    except Exception:
        if os.path.exists(tmp_path):
            os.unlink(tmp_path)
        raise


def _now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def _permanent_skips(data: dict | None) -> list:
    if not data:
        return []
    skips = data.get("permanently_skipped", [])
    return list(skips) if isinstance(skips, list) else []


def get_revision(log_path: str) -> None:
    data = _load(log_path)
    print("" if not data else data.get("revision", ""))


def has_milestone(log_path: str, milestone: str) -> int:
    data = _load(log_path)
    if not data:
        return 1
    milestones = data.get("completed_milestones", [])
    return 0 if milestone in milestones else 1


def has_skip(log_path: str, step: str) -> int:
    data = _load(log_path)
    return 0 if step in _permanent_skips(data) else 1


def mark_complete(log_path: str, revision: str, milestone: str) -> None:
    data = _load(log_path)
    if not data or data.get("revision") != revision:
        skips = _permanent_skips(data)
        data = {"revision": revision, "completed_milestones": []}
        if skips:
            data["permanently_skipped"] = skips
    data["revision"] = revision
    data["updated_at"] = _now()
    milestones = data.setdefault("completed_milestones", [])
    if milestone not in milestones:
        milestones.append(milestone)
    _save(log_path, data)


def mark_skip(log_path: str, step: str) -> None:
    data = _load(log_path)
    if not data:
        data = {"revision": "", "completed_milestones": []}
    data["updated_at"] = _now()
    skips = data.setdefault("permanently_skipped", [])
    if step not in skips:
        skips.append(step)
    _save(log_path, data)


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(
            "usage: _run_log.py get-revision LOG | has-milestone LOG MILESTONE | "
            "has-skip LOG STEP | mark-complete LOG REVISION MILESTONE | "
            "mark-skip LOG STEP",
            file=sys.stderr,
        )
        return 2

    command = argv[1]
    if command == "get-revision" and len(argv) == 3:
        get_revision(argv[2])
        return 0
    if command == "has-milestone" and len(argv) == 4:
        return has_milestone(argv[2], argv[3])
    if command == "has-skip" and len(argv) == 4:
        return has_skip(argv[2], argv[3])
    if command == "mark-complete" and len(argv) == 5:
        mark_complete(argv[2], argv[3], argv[4])
        return 0
    if command == "mark-skip" and len(argv) == 4:
        mark_skip(argv[2], argv[3])
        return 0

    print(f"unknown command or arguments: {' '.join(argv[1:])}", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
