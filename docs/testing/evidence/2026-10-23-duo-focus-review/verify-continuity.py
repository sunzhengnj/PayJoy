"""Verify this run's real session and debugger observations, not UI fixtures."""

import json
import math
from pathlib import Path
import re


folder = Path(__file__).parent
rows = [json.loads(line) for line in (folder / "persistence.jsonl").read_text().splitlines()]
by_label = {row["label"]: row["focus"] for row in rows}
started = by_label["started"]["active"]
paused = by_label["paused"]["active"]
session_id = started["id"]
assert started["plannedDuration"] == 120
assert not started["endsAtWork"]
assert paused["id"] == session_id
assert math.isclose(paused["pausedRemaining"], 81.68447995185852, abs_tol=0.001)
for label in ("paused-reopened", "paused-book", "paused-after-three-reopens", "after-background"):
    assert by_label[label]["active"] == paused, label

resumed = by_label["resumed-offwork-display"]["active"]
assert resumed["id"] == session_id
assert "pausedAt" not in resumed and "pausedRemaining" not in resumed
assert resumed["endDate"] > paused["endDate"]
for label in ("running-session-display", "running-offwork-display-again", "after-running-display-switch"):
    assert by_label[label]["active"] == resumed, label

before = json.loads((folder / "business-before.json").read_text())
after = json.loads((folder / "business-after.json").read_text())
focus_key = "payjoy.focus.data.v1"
before_records = before[focus_key]["records"]
for label in ("after-display-switch-deadline", "result-after-relaunch", "after-result-dismissal"):
    focus = by_label[label]
    assert "active" not in focus, label
    assert len(focus["records"]) == len(before_records) + 1, label
    record, = [record for record in focus["records"] if record["id"] == session_id]
    assert record["completed"] and record["focusedDuration"] == 120, label
    assert record["endedAt"] == resumed["endDate"], label
    assert [record for record in focus["records"] if record["id"] != session_id] == before_records, label
assert by_label["result-after-relaunch"]["pendingResultID"] == session_id
assert "pendingResultID" not in by_label["after-result-dismissal"]
for key in ("payjoy.salary.settings", "payjoy.wish.experiences.v1", "payjoy.engagement.state.v1"):
    assert before[key] == after[key], key

expected_idle = {
    "idle-default": False,
    "idle-focus-on": True,
    "idle-home": False,
    "idle-home-book": False,
    "idle-desk": True,
    "idle-background": False,
    "idle-returned": True,
    "idle-result": False,
    "awake-preference-reset": False,
}
for name, expected in expected_idle.items():
    output = (folder / f"{name}-lldb.log").read_text()
    value, = re.findall(r"\(bool\) \$\d+ = (true|false)", output)
    assert (value == "true") == expected, name
    assert "detached" in output, name

print("PASS: one real session; pause survives three reopens and background; display changes keep it running;")
print("120 focused seconds; one record after relaunch; salary, wishes and receipts unchanged;")
print("eight idle timer states verified and keep-awake preference reset to off.")
