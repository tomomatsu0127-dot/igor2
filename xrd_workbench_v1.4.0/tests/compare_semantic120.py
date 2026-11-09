"""Compare full native Igor dumps of the synthetic v1.1.0 -> v1.2.0 fixture.

Usage: python compare_semantic120.py DIRECTORY
DIRECTORY contains old/new_preinit/new_postinit/reopened.tsv from Igor.
This script never writes an Experiment or initializes Igor data.
"""
from pathlib import Path
import json
import sys


def read(path):
    rows = [line.split("\t", 1) for line in path.read_text(encoding="ascii").splitlines()]
    records = dict(rows)
    assert len(records) == len(rows), "Duplicate record keys"
    return records


def expected(key, before, after):
    if "|root:Packages:XRDWorkbench:UI:" in key:
        return key.endswith(":controls") or key.endswith(":geometry")
    if ":Comparison120" in key:
        return before is None  # new, project-scoped display settings only
    if key == "N|root:Packages:XRDWorkbench:PlotWorkspace:comparisonScope120":
        return before is None and after == "1"
    if key.startswith("S|") and key.endswith((":displayNormalization", ":protectedClasses")):
        return before == after + ";"  # existing initializer's list normalization
    if key.startswith("V3|") and key.endswith(":viewBaseline"):
        return before == "112.00000000000001" and after == "110"  # fixture's previous Y limit
    return False


def main(directory):
    old = read(directory / "old.tsv")
    summary = {}
    stages = {}
    for stage in ("new_preinit", "new_postinit", "reopened"):
        new = read(directory / (stage + ".tsv"))
        changed = sorted(key for key in old.keys() | new.keys() if old.get(key) != new.get(key))
        unexpected = [key for key in changed if not expected(key, old.get(key), new.get(key))]
        if stage == "new_preinit":
            unexpected = changed  # loading code alone must not mutate anything
        summary[stage] = {
            "old_records": len(old), "new_records": len(new),
            "all_changes": len(changed), "unexpected_changes": unexpected,
        }
        stages[stage] = new
    post, reopened = stages["new_postinit"], stages["reopened"]
    summary["save_restart_reopen"] = {
        "records": len(post),
        "changes": sorted(key for key in post.keys() | reopened.keys() if post.get(key) != reopened.get(key)),
    }
    (directory / "comparison_summary.json").write_text(
        json.dumps(summary, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2, ensure_ascii=False))
    assert not any(summary[s]["unexpected_changes"] for s in stages), "Unexpected persisted data changes"
    assert not summary["save_restart_reopen"]["changes"], "Save/restart/reopen changed persisted data"


if __name__ == "__main__":
    main(Path(sys.argv[1]))
