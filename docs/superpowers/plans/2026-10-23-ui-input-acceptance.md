# Duo Input Acceptance Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans inline. Preserve the existing 2.0.0 checkout and all user work.

**Goal:** Verify D12 and D13 through native controls, then verify draft retention across actual Duo poses.

**Architecture:** A separate PayJoyUITests target and scheme exercise existing Debug screenshot fixtures without adding production hooks. A test-only host handshake may drive Device Hub for folding; XCUIDevice orientation alone must not be described as folding. Fixture saves do not prove persistence; normal-mode save/relaunch checks remain separate.

**Tech Stack:** XCTest, XCUIAutomation, existing SwiftUI fixtures, one iOS 27.1 Duo simulator.

**Spec:** docs/testing/POST_RESTART_ACCEPTANCE.md, D12, D13, D15.

## Global Constraints

- Branch and app version stay 2.0.0; no release, upload or App review.
- At most two simulators and one build/test task; use one simulator here.
- Verify with low priority, one build job, disabled parallel WMO and actual one-thread Swift commands.
- No public APIs, new persisted fields or data migration; keep UI automation outside the shipping target.

## Review Focus

- Full-width/mixed-width digits and surrounding ideographic spaces must retain their draft and produce25/45-minute sessions.
- Invalid0,241,25.5 and25 minutes must leave Start disabled and no session visible.
- Japanese/German full-width decimal input must not become an integer100 times larger.
- A screenshot fixture's in-memory update is insufficient proof of saved values after process relaunch.
- Changing orientation without changing the hinge is insufficient proof of fold continuity.

### Task 1: Native input acceptance

- [x] Add an independent UI testing target/scheme without changing the app's release build action.
- [x] Add tests for valid/invalid focus input and Japanese/German salary input using actual fields and buttons. Attach runtime screenshots; use native keyboard entry without accessing the pasteboard.
- [x] Build for testing, run the UI scheme on Duo, inspect every failure and final result. Run the existing139-test suite after production changes, if any.

### Task 2: Actual pose and persistence checks

- [x] Use the working UI runner to keep input focused while Device Hub changes actual hinge poses; assert draft retention and actions remain reachable.
- [x] Verify salary Save→process relaunch→reopen in normal mode and restore the dedicated simulator's settings afterward.
- [x] Update acceptance evidence with exact scope and remaining gaps; commit/push the verified milestone on2.0.0.

## Execution ledger

- Base:3dac597. Existing139 unit tests and prior real timing evidence remain historical until corresponding current checks run.
- Ruling: use native UI automation for field actions — repeated window-coordinate taps depended on changing Device Hub frames — failed gestures could otherwise be mistaken for application behavior.

- Diagnostic: first UI smoke was cancelled in setUp before app launch; a process sample proved UIPasteboard.items was waiting for a system paste prompt. Removed clipboard access; the next run uses native typeText.

- RED: Native Save→reopen on original callbacks persisted Japanese full-width amount as12 instead of12345.67 (`PayJoySalaryUIClearOriginal20261023.xcresult`). The helper first confirms the existing field is empty, so this is not leftover input.
- Experiment: Removing only early returns did not resolve it (`PayJoySalaryUIDraftSync20261023.xcresult`); the visible value was already12. Rewriting the bound text during native full-width typing interrupts the draft. Normalize a copy for calculation; retain typed text until reload/preset/stepper formatting.
- RED: Native expanded-page query measured the minus button's hittable content at13pt despite a44pt layout frame. Add a rectangular content shape to both44pt stepper labels.
- Ruling: Group monthly paid days with payday/preview in the trailing column for salary/all modes. The same view hierarchy is retained across size changes and compact order remains amount→days→payday. This addresses the observed left-heavy form and right-side blank space without duplicating inputs.
- Ruling: XCUIScreen.main captures the inactive outer display on Duo. Enumerate XCUIScreen.screens and review display1; keep display0 labelled. XCUIApplication.frame aspect alone is not evidence of the active inner layout; compare controls with the actual ScrollView viewport.
- Resource finding: Xcode cancellation/failures can launch600-second simctl diagnose collectors. Stop only this task's identified collectors; future routine runs use -collect-test-diagnostics never and keep targeted logs/screenshots/result bundles.

- GREEN (four input/layout cases): `PayJoyInputUIPreserveDraft20261023.xcresult` passed valid focus, invalid focus, Japanese/German Save→reopen and expanded stepper bounds. Its extra display-switch case failed before any switch: the root focus fixture still had active overtime, so the time menu was correctly unavailable. Do not count that run as an entirely passing suite.
- Fixture correction: exclude sample overtime from `featured-focus-tab`, matching the existing `focus-*`/featured-home fixtures. Normal mode timing rules are unchanged. The next hierarchy confirmed the time Menu is a Button; the earlier PopUpButton mismatch concerned the unrelated settings menu. Use the time Button’s first match in the transient presentation hierarchy. No production menu change is needed.

- Task1 verified: four input/layout tests passed in PayJoyInputUIFinal20261023.xcresult. Its extra display case still used the wrong PopUpButton query; final Button query passed as a targeted rerun in PayJoyFocusDisplayUICleanLaunch20261023.xcresult. A separate transient start tap did not enter a session, then the same source passed on retry; cause unproven, not recorded as a production fix.
- Current139/139 iOS unit tests passed,0failed/0skipped, PayJoyInputUnit20261023.xcresult. Source hashes, per-case status and retained failure are verified by docs/testing/evidence/2026-10-23-input-ui/verify-results.py. Task2 remains open for actual hinge draft/focus and normal-mode process persistence.
- Review finding to carry into Task2: native time-menu label frame was about81×19pt. Verify its full hit region against the44pt target while correcting actual pose boundaries; do not claim that this milestone passed every focus control's touch area.

- Task2 in progress: real Device Hub actions are acknowledged through a test-only file handshake. The first run passed both full-width draft/caret cycles, including external-screen Closed→Open, and the menu now measures44pt. Its normal-mode persistence case reused an already-equal target value, so it is insufficient proof of a new write. Strengthen it with a24123.89/20.5 baseline verified after relaunch before writing12345.67/21.75. Also verify primary-action reachability in each fold pane, returning explicitly to editing afterward.
- Ruling: use an explicit live Device Hub PID, validated from the current process inventory. NSRunningApplication's bundle lookup returned a stale pid=-1 record on this host; AX access to the known Device Hub PID succeeds. The control tool rejects missing buttons/actions instead of silently treating them as success.
- Native menu hit-area RED: the time selector measured19.333pt high; add a44pt minimum frame and rectangular contentShape without changing timing semantics. A targeted display switch remains running after the change.
- Task2 intermediate: four strengthened UI cases passed, including primary-action hit testing and normal-mode contrasting baseline→save→cold relaunch→restore for both regions.139 iOS unit cases passed on retry; the earlier test-host connection timeout is retained and its cause remains unproven.
- Additional combination: move actual half-fold→rotate→open into the normal-mode edit/save/relaunch case. Its first run passed Japanese, then failed the German field-clear precondition before the second save; the dedicated simulator retained the temporary24123.89/20.5 baseline. Recovery and final combined acceptance are required before this task is complete.
- Diagnostic: tapping the visual end and deleting by string count can leave a suffix after rotation. Native command-A also failed to select the field in this test (actual24123,8 after one delete); neither failure proves a product persistence defect. The native editing menu restored the original settings once, but a subsequent run failed for placeholder-only input and missing edit menus after opening. Captured business fields still matched the original after that run.
- Diagnostic: typeText(forwardDelete) inserts its private character instead of deleting; typeKey(leftArrow) did not move the caret in a targeted probe. Retain both failed summaries; do not count those event methods as successful input verification.
- Correction: salary replacement now drags the caret by touch, types7 and asserts it was appended, then deletes exactly the existing length plus1 and verifies empty before typing the requested value. Fresh empty focus fields are typed directly. The Japanese/German fixture Save→reopen case passed with this helper.
- Complete8-case run:7passed,1failed,0skipped. Valid/invalid focus inputs, display switching, expanded salary controls and both actual draft/caret cycles passed. Normal-mode persistence failed its caret precondition:20.5 became20.75 instead of20.57, so no target was saved. A drag ending inside the trailing-aligned short field can still stop before the last glyph. Move the endpoint24pt past the field's trailing edge, restore original settings, then rerun only that affected normal-mode case. Keep the failed run distinct from the seven successful cases.

- Task2 verified: the seven UI cases remain individually passed in PayJoyDuoInputAccepted20261023.xcresult (its normal-mode precondition failed). After correcting only the QA drag endpoint, the affected normal-mode fold/save/relaunch case passed in PayJoySalaryFoldSaveRelaunchFixed20261023.xcresult, both regions, with7actual pose acknowledgements. Original three business fields were independently restored;202local screenshots are indexed. Current application source matches139/139 iOS unit verification. The larger Goal and acceptance matrix remain open.
