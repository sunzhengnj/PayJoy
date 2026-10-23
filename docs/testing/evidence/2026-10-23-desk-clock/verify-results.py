"""Check local milestone evidence; this does not approve the full release Goal."""
import hashlib
import json
import sys
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


passed("desk-final-summary.json", 6)
passed("preferences-green-summary.json", 2)
passed("unit-final-summary.json", 141)
passed("normal-final-summary.json", 2)
if "--checkpoint" in sys.argv:
    for row in read("pause-source-files.json"):
        assert hashlib.sha256((repo / row["file"]).read_bytes()).hexdigest() == row["sha256"], row["file"]
    for row in read("review-fixed-source-files.json"):
        if row["file"].startswith(("PayJoy/", "PayJoyTests/")):
            assert hashlib.sha256((repo / row["file"]).read_bytes()).hexdigest() == row["sha256"], row["file"]
    for build in read("pause-build-flags.json"):
        assert build["testBuildSucceeded"], build["log"]
        assert build["swiftNumThreads"] == ["1"], build["log"]
        assert build["swiftJobs"] == ["1"], build["log"]
    assert read("phone-normal-restored.json")["allPayJoyKeysMatchBefore"]
    assert read("preferences-restored.json")["otherKeysUnchanged"]
    phone = read("phone-final-first-summary.json")
    assert phone["passedTests"] == 4 and phone["failedTests"] == 1
    assert read("phone-viewport-failure-summary.json")["failedTests"] == 1
    status = read("pause-status.json")
    assert status["status"] == "paused" and not status["milestoneComplete"]
    print("CHECKPOINT VALIDATED: recorded Duo141/141,Desk6/6,preferences2/2,normal/profile2/2.")
    print("Current source/build provenance and test-simulator restoration checked.")
    print("PAUSED,INCOMPLETE:phone salary viewport and normal-store isolation remain open.")
    sys.exit(0)

passed("phone-viewport-summary.json", 1)
assert read("preferences-red-summary.json")["failedTests"] == 2
assert read("geometry-native-summary.json")["failedTests"] == 1
assert read("stable-shell-startup-summary.json")["testFailures"][0]["failureText"] == "Testing was canceled"
phone = read("phone-final-first-summary.json")
assert phone["passedTests"] == 4 and phone["failedTests"] == 1
assert phone["testFailures"][0]["testName"] == "testFullWidthSalaryDecimalsFollowTheRegion()"
assert read("unit-phone-first-summary.json")["passedTests"] == 140

ordinary = read("normal-business-after-preferences-red.json")
assert read("normal-business-after-preferences-green.json") == ordinary
assert read("normal-business-after-desk-final.json") == ordinary
assert read("phone-normal-comparison.json")["identical"], "Phone fixture storage isolation is still open"
assert read("preferences-restored.json")["otherKeysUnchanged"]
restored = read("preferences-restored.json")["keys"]
assert restored["payjoy.focus.keepScreenAwake"]["after"] is False
assert not restored["payjoy.boss.key.didShowExitGuide"]["existsAfter"]
before, after = read("normal-mode-business-before.json"), read("normal-mode-business-after.json")
for state in (before, after):
    # SalarySettings uses Set<Int>; compare its members, preserve raw snapshots.
    state["payjoy.salary.settings"]["workdays"] = sorted(state["payjoy.salary.settings"]["workdays"])
assert before == after

pose_counts = {}
for name in ("review-fixed-desk", "normal-final"):
    events = [json.loads(line) for line in (folder / name / "pose-events.jsonl").read_text().splitlines()]
    assert len({e["id"] for e in events}) == len(events)
    assert all((repo / e["screenshot"]).is_file() for e in events)
    for event in events:
        if event.get("readsLayout"):
            assert event["layout"]["axis"] in {"horizontal", "vertical"}
    pose_counts[name] = len(events)
    if name == "normal-final":
        assert any(e.get("layout", {}).get("axis") == "horizontal"
                   and all(s in e["layout"]["gate"] for s in ("tab=profile", "hidden=false", "can=true", "show=false"))
                   for e in events if e.get("layout"))
assert pose_counts["review-fixed-desk"] == 31

for row in read("final-source-files.json"):
    assert hashlib.sha256((repo / row["file"]).read_bytes()).hexdigest() == row["sha256"], row["file"]
for row in read("review-fixed-source-files.json"):
    if row["file"].startswith("PayJoy/") or row["file"].startswith("PayJoyTests/"):
        assert hashlib.sha256((repo / row["file"]).read_bytes()).hexdigest() == row["sha256"], row["file"]
for row in read("screenshot-index.json"):
    assert hashlib.sha256((folder / row["file"]).read_bytes()).hexdigest() == row["sha256"], row["file"]
assert read("final-build-flags.json")["swiftNumThreads"] == ["1"]
assert read("final-build-flags.json")["swiftJobs"] == ["1"]
print("PASS:141 unit cases;6 Desk cases;2 preference cases;normal persistence and stronger profile gate;")
print("four phone cases plus the affected salary case's rerun;stored-data/source/image checks.")
print("Startup,StoreKit and UI failures retained;full release/physical-device acceptance remains open.")
