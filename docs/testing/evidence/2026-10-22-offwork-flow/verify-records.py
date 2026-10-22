from pathlib import Path
import json, math
folder = Path(__file__).parent
rows = [json.loads(line) for line in (folder/'persistence.jsonl').read_text().splitlines()]
by_label = {row['label']:row['focus'] for row in rows}
started = by_label['offwork-started']['active']
resumed = by_label['offwork-resumed']['active']
finished = by_label['offwork-deadline-result']
session_id = 'C9B00439-6D29-4F51-8614-DE70A5B5AF55'
assert started['id'] == resumed['id'] == session_id
assert started['endsAtWork'] and started['endDate'] == resumed['endDate'] == 814370700
record, = [r for r in finished['records'] if r['id'] == session_id]
assert 'active' not in finished and record['completed']
assert record['endedAt'] == 814370700
assert math.isclose(record['focusedDuration'], 361.10181498527527, abs_tol=0.001)
assert math.isclose(started['plannedDuration'] - resumed['accumulatedPause'], record['focusedDuration'], abs_tol=0.001)
assert len([r for r in by_label['after-manual-receipt']['records'] if r['id'] == session_id]) == 1
before = json.loads((folder/'business-before-result.json').read_text())
at_result = json.loads((folder/'business-at-result.json').read_text())
after = json.loads((folder/'business-after-receipt.json').read_text())
assert not at_result['payjoy.engagement.state.v1']['capsules']
receipt, = after['payjoy.engagement.state.v1']['capsules']
assert receipt['dateKey'] == '2026-10-22'
assert math.isclose(receipt['earnedAmount'], 454.54545454545456, abs_tol=0.001)
assert before['payjoy.wish.experiences.v1'] == at_result['payjoy.wish.experiences.v1'] == after['payjoy.wish.experiences.v1']
print('PASS: fixed work deadline, pause excluded, one focus record, receipt only after user action, empty wish store unchanged.')
