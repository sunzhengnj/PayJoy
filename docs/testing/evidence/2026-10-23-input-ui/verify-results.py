"""Check individual UI outcomes, retained failures, unit results and source hashes."""

import hashlib
import json
from pathlib import Path


folder = Path(__file__).parent
repo = folder.parents[3]


def read(name):
    return json.loads((folder / name).read_text())


def cases(tree):
    if isinstance(tree, dict):
        if tree.get("nodeType") == "Test Case":
            yield tree["name"], tree["result"]
        for value in tree.values():
            yield from cases(value)
    elif isinstance(tree, list):
        for value in tree:
            yield from cases(value)


inputs = dict(cases(read("input-regression-tests.json")))
display_name = "testChangingClockDisplayKeepsFocusRunning()"
for name in (
    "testFullWidthFocusMinutesStartTheRequestedDuration()",
    "testInvalidFocusMinutesCannotStartASession()",
    "testFullWidthSalaryDecimalsFollowTheRegion()",
    "testExpandedSalaryInputsFitWithoutScrolling()",
):
    assert inputs[name] == "Passed", name
assert inputs[display_name] == "Failed"  # Retain the earlier query failure.
assert read("input-regression-summary.json")["failedTests"] == 1
assert dict(cases(read("display-regression-tests.json")))[display_name] == "Passed"
for name, count in (("display-regression-summary.json", 1), ("unit-summary.json", 139)):
    summary = read(name)
    assert summary["passedTests"] == summary["totalTestCount"] == count
    assert summary["failedTests"] == summary["skippedTests"] == 0
for row in read("final-source-files.json"):
    assert hashlib.sha256((repo / row["file"]).read_bytes()).hexdigest() == row["sha256"], row["file"]

print("PASS: four input/layout UI cases; display-switch targeted rerun; 139 unit tests.")
print("The earlier mixed UI bundle retains one failure; this is not a single all-green UI run.")
