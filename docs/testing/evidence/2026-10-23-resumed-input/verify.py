"""Verify this incremental evidence set, not the full development Goal."""
import hashlib
import json
from pathlib import Path

folder = Path(__file__).resolve().parent
repo = folder.parents[3]

def read(name):
    return json.loads((folder / name).read_text())

for name, count in [('phone-green-summary.json', 5), ('calendar-summary.json', 1)]:
    result = read(name)
    assert result['result'] == 'Passed'
    assert result['passedTests'] == result['totalTestCount'] == count
    assert result['failedTests'] == result['skippedTests'] == 0
assert read('viewport-red-summary.json')['failedTests'] == 1
assert read('normal-store-comparison.json')['identical']
assert read('normal-store-comparison.json')['keysBefore'] == 14
for name in ['build-flags.json', 'calendar-build-flags.json']:
    flags = read(name)
    assert flags['succeeded'] and flags['swiftNumThreads'] == flags['swiftJobs'] == ['1']
for row in read('final-source-files.json'):
    assert hashlib.sha256((repo / row['file']).read_bytes()).hexdigest() == row['sha256'], row['file']
# Earlier unit/Desk results apply to the same unchanged production and unit source.
for row in json.loads((folder.parent / '2026-10-23-desk-clock/review-fixed-source-files.json').read_text()):
    if row['file'].startswith(('PayJoy/', 'PayJoyTests/')):
        assert hashlib.sha256((repo / row['file']).read_bytes()).hexdigest() == row['sha256'], row['file']
for row in read('screenshot-index.json'):
    assert hashlib.sha256((folder / row['file']).read_bytes()).hexdigest() == row['sha256'], row['file']
events = [json.loads(line) for line in (folder / 'calendar-cua-events.jsonl').read_text().splitlines()]
assert len({event['id'] for event in events}) == 6
assert [event['action'] for event in events] == ['Open', 'Partially Open', 'Rotate Right', 'Open', 'Closed', 'Open']
assert read('mcp-status.json')['version'] == '2.7.0'
print('PASS: recorded phone5/5 and Duo calendar1/1; unchanged product source, media and14-key comparison verified.')
print('Historical store mutation, full navigation/scroll, privacy, performance and device acceptance remain open.')
