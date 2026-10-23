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

- [ ] Use the working UI runner to keep input focused while Device Hub changes actual hinge poses; assert draft retention and actions remain reachable.
- [ ] Verify salary Save→process relaunch→reopen in normal mode and restore the dedicated simulator's settings afterward.
- [ ] Update acceptance evidence with exact scope and remaining gaps; commit/push the verified milestone on2.0.0.

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
