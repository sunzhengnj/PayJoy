"""Run one native UI acceptance job and acknowledge actual Device Hub pose changes.

Build PayJoyPoseUITests first. Pass output folder, compiled pose-control path,
then the xcodebuild test-without-building command after --.
"""

import argparse
import json
from pathlib import Path
import re
import subprocess
import time

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--control", type=Path, required=True)
parser.add_argument("--device-hub-pid", type=int, required=True)
parser.add_argument("command", nargs=argparse.REMAINDER)
args = parser.parse_args()
command = args.command[1:] if args.command[:1] == ["--"] else args.command
if not command:
    parser.error("Missing test command")
args.output.mkdir(parents=True, exist_ok=False)
log_path = args.output / "pose-tests.log"
events = args.output / "pose-events.jsonl"
seen = set()
actions = {"Open", "Partially Open", "Closed", "Rotate Right"}

with log_path.open("w") as output:
    process = subprocess.Popen(command, stdout=output, stderr=subprocess.STDOUT)
    try:
        while process.poll() is None:
            text = log_path.read_text(errors="replace")
            for match in re.finditer(r"PAYJOY_DUO_POSE_REQUEST (.+payjoy-duo-pose-[A-F0-9-]+\.json)", text):
                request_path = Path(match[1].strip())
                if request_path in seen:
                    continue
                seen.add(request_path)
                request = json.loads(request_path.read_text())
                if request["action"] not in actions or request["ack"] != str(request_path) + ".ack":
                    raise ValueError("Invalid pose request")
                layout_path = None
                previous_axis = None
                if request.get("readsLayout"):
                    container = subprocess.run(["xcrun", "simctl", "get_app_container", request["udid"], "app.payjoy.kaixin", "data"], check=True, capture_output=True, text=True, timeout=5)
                    layout_path = Path(container.stdout.strip()) / "tmp/payjoy-desk-layout.json"
                    if layout_path.exists():
                        previous_axis = json.loads(layout_path.read_text())["axis"]
                action_started = time.time()
                result = subprocess.run([str(args.control), request["action"], str(args.device_hub_pid)], check=True, capture_output=True, text=True)
                control = json.loads(result.stdout)
                time.sleep(3)
                layout = None
                if layout_path:
                    deadline = time.monotonic() + 12
                    stable_since = time.monotonic()
                    signature = None
                    while time.monotonic() < deadline:
                        if layout_path.exists():
                            candidate = json.loads(layout_path.read_text())
                            valid = candidate["updatedAt"] >= action_started and candidate["axis"] in {"horizontal", "vertical"}
                            if request["action"] == "Rotate Right":
                                valid = valid and candidate["axis"] != previous_axis
                            current = candidate["gate"] if valid else None
                            if current != signature:
                                signature, stable_since = current, time.monotonic()
                            if valid and time.monotonic() - stable_since >= 0.8:
                                layout = candidate
                                break
                        time.sleep(0.1)
                    if layout is None:
                        raise RuntimeError("No fresh, stable division geometry from the Debug app")
                screenshot = args.output / f"pose-{len(seen):02d}-{request['action'].replace(' ', '-')}.png"
                subprocess.run(["screencapture", "-x", "-o", f"-l{control['windowID']}", str(screenshot)], check=True)
                with events.open("a") as ledger:
                    ledger.write(json.dumps({**request, "time": time.time(), "windowID": control["windowID"], "screenshot": str(screenshot), "layout": layout}) + "\n")
                ack = {"id": request["id"], "action": request["action"]}
                if layout:
                    ack["axis"] = layout["axis"]
                Path(request["ack"]).write_text(json.dumps(ack))
            time.sleep(0.1)
    except BaseException:
        process.terminate()
        process.wait(timeout=30)
        raise
    finally:
        subprocess.run([str(args.control), "Open", str(args.device_hub_pid)], capture_output=True)
    raise SystemExit(process.returncode)
