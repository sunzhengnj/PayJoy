# Duo Desk Clock Acceptance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans inline. Reuse the authorized2.0.0 checkout and the existing single-Duo host handshake.

**Goal:** Verify the desk clock's automatic-entry gates, independent clock/control areas and work-state actions against the approved Duo requirements.

**Architecture:** Native UI tests drive actual Device Hub folding. Debug fixtures supply deterministic business inputs through the existing screenshot host; their SettingsStore must be isolated from normal app and widget data. Normal-mode business calculation and persisted formats stay unchanged.

**Tech Stack:** SwiftUI, XCTest/XCUIAutomation, iOS27.1 Duo, existing QA host tools.

**Spec:** The user-approved Duo plan; docs/product/DUO_REQUIREMENTS_AUDIT.md; docs/testing/POST_RESTART_ACCEPTANCE.md D02, D03, D06.

## Current status

Active again after the user's explicit resume. Neither task is marked complete. Duo141 unit cases,6 Desk cases,2 preference cases and2 normal/profile cases are recorded passing on unchanged production source. New ordinary-phone5/5 and Duo calendar-continuity1/1 passed. The suspected keyboard-save defect was not reproduced;only the UI test gesture was corrected. Historical normal-store mutation and the remaining full Goal matrix stay open. See docs/testing/evidence/2026-10-23-resumed-input/README.md.

## Global Constraints

- Keep2.0.0(11), iOS17 minimum, current branch; no archive/upload/release.
- One build/test job, preferably one simulator, maximum two; actual Swift threads1 and low priority. No automatic CPU abort.
- Use actual hinge actions. Fixed-time fixtures prove state/routing/layout, not real elapsed-time settlement or device-only services.
- No public API, persisted-field or migration changes. Raw media stay local; milestones are committed and pushed automatically.

## Review Focus

- Fixture writes must not modify the normal app's or widget's defaults.
- A missing desk clock on an edit page must not pass merely because the device is in book pose.
- No next workday means休息中, not a fabricated zero countdown.
- Cancelling overtime completion must leave the active session; confirming opens the existing receipt flow without accepting it for the user.
- An element's native hit test is not proof of every keyboard, camera or short-pane combination.

### Task 1: Native clock/state acceptance with isolated fixtures

**Files:** SettingsStore.swift, PayJoyApp.swift, AppState.swift; SalaryCalculatorTests.swift; new PayJoyUITests/DeskClockAcceptanceTests.swift and DuoAcceptanceSupport.swift; existing UI target registration and InputAcceptanceTests shared helpers.

**Interfaces:** Reuse AppState/DeskClockView and the existing requestPose/action acknowledgement protocol. Add an internal Debug-only SettingsStore.screenshotFixture() factory and call it only when screenshot mode is active.

- [ ] Add testScreenshotFixtureStoreDoesNotWriteNormalDomainsAndStartsFresh. Save salary, overtime and early-leave values into the fixture store; verify ordinary/shared defaults are unchanged and a new fixture store starts empty. Watch the missing-factory test fail before implementation.
- [ ] Implement the minimal Debug store factory and app construction guard; release and normal-mode stores stay on their current path.
- [ ] Move only the three already-tested host/screenshot helpers into UI test support; register the two new files without changing shipping sources.
- [ ] Add actual desk-entry/suppression and edit/modal blocking tests. First demonstrate successful tabletop entry, then exercise negative gates in that known orientation; require explicit Open before suppression can clear. Check native header/actions at least44pt, black/white switching and no salary amount in the clock.
- [ ] Add deterministic state test inputs: working June3 15:24→03:06:00; lunch12:30→06:00:00 with lunch label; before08:00→01:30:00; after19:00→14:30:00; Sunday June7 15:24→18:06:00; no workdays→休息中; overtime June3 22:45→June4 00:18→01:33:00. Run before adding missing fixture data; record fixture failures separately from product failures.
- [ ] Supply those Debug fixture inputs and root routes. Exercise overtime cancel/confirm and early-close UI; fix actual product defects only after a reproducing failure.
- [ ] Run the relevant UI tests and complete141-case iOS unit suite; inspect actual Device Hub and native screenshots, compare normal business data before/after, and retain every failure's scope.

### Task 2: Review and deliver the verified milestone

- [ ] One independent review of the whole plan range; correct Important/Critical findings with a failed-first regression and relevant green suite. Record unjudged requirements explicitly.
- [ ] Update D02/D03/D06 only to the scope actually proved. Camera/short-pane, real settlement and the rest of the full Goal remain open if not measured here.
- [ ] Close this task's simulator and residual processes, validate the diff and evidence, commit/push2.0.0 and verify the remote SHA.

## Execution ledger

- Base:ef841a1; previous turn made progress: verified/pushed input continuity and44pt focus selector, not full Goal completion.
- Pre-flight: state fixtures and UI tests share the existing root route and host protocol. New default-store isolation must precede overtime/early-close UI writes; normal-mode persistence tests from the previous milestone keep normal stores.

- RED: store test compilation failed only because screenshotFixture did not exist. Implemented the Debug factory; UI build is green. Real working-clock fixture passed before the missing lunch fixture failed its expected-label check (PayJoyDeskStateRed20261023.xcresult).
- Ruling: preserve existing overtime accounting — current SalaryCalculator does not add an hourly overtime wage; the previous-day receipt target is18000/21.75=827.59, not a new overtime-pay calculation — changing that product rule later requires revising this expectation.

- Native first run: automatic entry/suppression/appearance and editor blocking passed. Lunch/before/after/rest clocks passed; no-next fixture failed because SalarySettings.init normalizes empty workdays, so set the fixture property after construction without changing model rules. Early-close confirmation was visible in the upper pane but the unscoped hit test failed; scope to its dialog and inspect reachability.
- Ruling correction: historical calendar salary uses actual regular workdays,22in June2026; the cross-midnight target is18000/22=818.18. The earlier827.59was the current-day fun estimate, not the historical receipt rule. The first unscoped money predicate matched background content; actual receipt screenshot shows0.00. Tighten the assertion to the receipt scroll before changing production display.

- Receipt RED: scoped native check failed with visible0.00in the receipt; previous-day818.18was missing. Added a core preview/saved-amount regression; compilation failed on the missing shared property, then implemented a shared AppState amount projection and used it for preview and existing completion logic.
- Early-close diagnosis: scoped native hit check remained false although the47.5pt buttons were visible inside the upper pane. Next check uses an actual centre touch and requires the expected cancel/confirm response; a hit-test flag alone is not a product fix.

- Latest geometry-driven run completed:5 passed,1 failed (PayJoyDeskGeometryNative20261023.xcresult). SDK layout confirmed horizontal tabletop but homeRootVisible stayed false during the early-close test's initial entry. This is a real initial navigation-shell/visibility race; it is still unfixed. Proposed next investigation: keep the tab shell stable when hinge capability becomes available, then verify ordinary iPhone navigation as well as Duo.
- Fixture-only preference comparison:15 keys before/after. Salary, overtime, early leave and other business keys are byte-identical; one analytics aggregate key (payjoy.analytics.aggregate.mainlandChina.closingReceiptOpened) changed. Do not claim all ordinary defaults are isolated. The fixture-specific SettingsStore does not cover that separate analytics writer.
- Work stopped at a project-scope clarification after the user attached a Westward level-map screenshot. Current changes remain uncommitted and this milestone is incomplete:141-case unit run, normal-mode persistence, stable-shell fix, independent review and final delivery are pending.

- Resumed the active PayJoy Goal. Ruling: keep one TabView shell after onboarding on both device classes and hide the system bar on ordinary iPhone. The existing comic bar remains; this avoids destroying/recreating Home/NavigationStack when asynchronous Duo capability first arrives. The last failing native test is the RED case; ordinary-iPhone regression is required because its shell also changes.

- Analytics isolation RED was the fixture-only snapshot comparison:only closingReceiptOpened in the normal aggregate domain changed. Injected LocalEngagementAnalytics into the screenshot AppState using the same fixture domain; expanded the store regression to check aggregate reset and ordinary-domain retention. Normal analytics construction remains unchanged.

- Stable-shell targeted UI attempt was explicitly interrupted after the application launch request made no further progress for about10 minutes (754.996s total XCTest operation). Exit75; no desk-layout assertion result. Result and startup log retained. The runner was alive before cancellation; it was not silently treated as finished or restarted. App-root correction remains unverified by native UI. Stopped the separate symbolication probe and requested own Duo shutdown. Next available work: compile all141 unit cases and run them on the ordinary-iPhone runtime, then resume Duo after actual runtime readiness.

- Ordinary iPhone boot completed in12s. Full141-case run reached all tests:140 passed; existing local StoreKit product load failed with productUnavailable. A targeted warm repeat failed again. Ruling: make the test own an explicit SKTestSession from a test-target-only copy of the existing StoreKit configuration. No production purchase code or product identifiers change; this validates the local product loading contract without relying on scheme/runtime activation behavior.

- StoreKit experiment did not resolve the failure:explicit SKTestSession logged SKInternalErrorDomain code3 while saving configuration, applying overrides and resetting. Full run stayed140/141. Reverted the experiment and test-resource registration rather than retaining an unproved test fix. Product loading code is unchanged. Original141-case run remains authoritative; StoreKit local-service activation on iOS26.5 is still open.

- Phone native UI:focus duration and regional salary passed; clock selector failed because startFocus replaced the fixed screenshot work-time with real Date() after19:00. Not a phone-menu layout defect and not a reason to expose off-work options in normal after-work state. Ruling:reuse the frozen AppState.now for screenshot focus interactions and foreground restoration; normal mode still samples Date(). Native failed selector is the RED case. No timezone change was made.

- Corrected clock UI passed on iPhone (17.818s), custom focus inputs passed (24.299s). The regional salary test failed before entering its paid-days replacement:the existing helper dragged outside the short field and typeText reported no keyboard focus. The prior phone run's salary test passed41.452s; the new run is still2/3, not3/3. No salary implementation was changed.

- Review fixes:both native preference regressions RED→GREEN; all16 ordinary keys match the post-RED baseline after both preference tests and all six Desk cases. The two intentional RED preference changes are pending restoration at simulator shutdown. No matching App Group container was found in this ad-hoc install; runtime widget isolation remains unjudged.
- Six reviewed Desk cases all passed with31 actual pose acknowledgements. Final141-case Duo unit suite passed141/141,0 skipped; the iOS26.5 StoreKit failure remains retained, not relabeled as an app regression or removed from history.
- Ruling:the keyboard editor's effective height325.67 makes canShowDeskClock=false even with a horizontal SDK axis. Add an independent profile-root negative check without keyboard and require its trace to showcan=true, before entering the editor. Keep the keyboard draft check as a separate continuity case.
- Phone caret-helper RED reported no keyboard focus after dragging outside a short field. Return the tap explicitly inside the field at its right edge before typing the sentinel; retain the append assertion before clearing or saving. Normal-mode persistence is rerun on the ready Duo.

- Pause checkpoint:normal-mode persistence and stronger profile gate passed2/2. Latest phone five-case run4/5; visibility-helper salary rerun still failed after saving. New viewport-height assertion compiled successfully but was not run before the user requested pause. No salary save implementation change. Final phone normal-domain comparison found two business keys changed; restored only these test-machine keys after shutdown, all14 keys now match baseline. Do not mark full fixture isolation accepted.

- Resumed by explicit user instruction. No product keyboard fix:the new height predicate passed for Japanese;the next failure showed default test swipe landing on keyboard coordinates. Restricted test drag to the content between navigation and save footer. Five phone regressions5/5,normal14 keys byte-identical. Prior two-key mutation is not reproduced but remains unresolved historically. Installed and MCP-verifiedXcodeBuildMCP2.7.0 under user authorization.

- Additional original-D07 acceptance:calendar date and navigation stack survive actualPartially Open/Rotate Right/Open/Closed/Open actions;native1/1 passed160.140s. Source product unchanged. Keep all-page scroll,privacy,performance and historical store anomaly open;this is incremental progress,not full-plan completion.
