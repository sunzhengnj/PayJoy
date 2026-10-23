"""Verify local pose/input evidence without treating a green subset as release approval."""

import hashlib
import json
from pathlib import Path


folder = Path(__file__).resolve().parent
repo = folder.parents[3]


def read(name):
    return json.loads((folder / name).read_text())


def passed(name, count):
    result = read(name)
    assert result["result"] == "Passed", name
    assert result["totalTestCount"] == result["passedTests"] == count, name
    assert result["failedTests"] == result["skippedTests"] == 0, name


passed("final-summary.json", 4)
accepted = read("accepted-first-summary.json")
assert accepted["result"] == "Failed"
assert accepted["totalTestCount"] == 8 and accepted["passedTests"] == 7
assert accepted["failedTests"] == 1 and accepted["skippedTests"] == 0
assert accepted["testFailures"][0]["testName"] == "testNormalSalarySurvivesProcessRelaunch()"
passed("combined-fixed-summary.json", 1)
passed("caret-drag-summary.json", 1)
passed("unit-summary.json", 139)
assert read("menu-red-summary.json")["failedTests"] == 1
assert "19.333" in json.dumps(read("menu-red-summary.json"))
assert read("unit-launch-failure-summary.json")["result"] == "Failed"
assert read("combined-first-failure-summary.json")["result"] == "Failed"

for name, expected in (
    ("final", ["Open", "Partially Open", "Rotate Right", "Open", "Closed", "Open", "Open",
               "Open", "Partially Open", "Rotate Right", "Open", "Closed", "Open"]),
    ("accepted", ["Open", "Partially Open", "Rotate Right", "Open", "Closed", "Open", "Open",
                  "Open", "Partially Open", "Rotate Right", "Open", "Closed", "Open"]),
    ("combined-fixed", ["Open", "Partially Open", "Rotate Right", "Open", "Partially Open", "Rotate Right", "Open"]),
):
    events = [json.loads(line) for line in (folder / name / "pose-events.jsonl").read_text().splitlines()]
    assert [event["action"] for event in events] == expected, name
    assert len({event["id"] for event in events}) == len(expected), name
    assert all((repo / event["screenshot"]).is_file() for event in events), name

before = read("normal-business-before.json")
for name in ("normal-business-after.json", "normal-business-after-all-tests.json",
             "normal-business-restored.json", "normal-business-after-menu-failure.json", "normal-business-final.json"):
    after = read(name)
    # SalarySettings encodes workdays as Set<Int>; preserve raw snapshots but compare its members.
    for state in (before, after):
        settings = state["payjoy.salary.settings"]
        settings["workdays"] = sorted(settings["workdays"])
    assert after == before, name

for row in read("combined-fixed-source-files.json"):
    assert hashlib.sha256((repo / row["file"]).read_bytes()).hexdigest() == row["sha256"], row["file"]
for row in read("first-source-files.json"):
    if row["file"] in ("PayJoy/Views/FocusView.swift", "PayJoy/Views/SalarySettingsView.swift"):
        assert hashlib.sha256((repo / row["file"]).read_bytes()).hexdigest() == row["sha256"], row["file"]
for row in read("screenshot-index.json"):
    assert hashlib.sha256((folder / row["file"]).read_bytes()).hexdigest() == row["sha256"], row["file"]

print("PASS: seven UI cases plus the affected normal-mode case's targeted rerun; 139 unit tests;")
print("13 historical + 13 current + 7 rerun pose acknowledgements, restored business fields and screenshot hashes.")
print("Initial failures retained; full release acceptance remains open.")
