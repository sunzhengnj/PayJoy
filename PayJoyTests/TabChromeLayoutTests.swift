import SwiftUI
import XCTest
@testable import PayJoy

final class TabChromeLayoutTests: XCTestCase {
    func testTallWindowUsesSingleColumnInsteadOfHidingSecondaryArrangement() {
        var layout = AdaptiveLayoutContext(
            size: CGSize(width: 800, height: 1000), safeAreaInsets: EdgeInsets(),
            divisionRegions: [], occlusionRegions: []
        )
        XCTAssertFalse(layout.hasRoomForTwoColumns,
                       "A horizontal-only system arrangement hides its secondary view in a tall window")
        layout.size = CGSize(width: 1000, height: 800)
        XCTAssertTrue(layout.hasRoomForTwoColumns)
    }

    func testHorizontalFoldFallsBackToOneScrollablePane() {
        var layout = AdaptiveLayoutContext(
            size: CGSize(width: 800, height: 600), safeAreaInsets: EdgeInsets(),
            divisionRegions: [CGRect(x: 0, y: 120, width: 800, height: 20)], occlusionRegions: []
        )
        XCTAssertFalse(layout.hasRoomForTwoColumns)
        XCTAssertEqual(layout.singleColumnBounds, CGRect(x: 0, y: 152, width: 800, height: 448))
        layout.divisionRegions = [CGRect(x: 0, y: 450, width: 800, height: 20)]
        XCTAssertEqual(layout.singleColumnBounds, CGRect(x: 0, y: 0, width: 800, height: 438))
    }

    func testSinglePaneClearsCameraAcrossItsFullWidth() {
        var layout = AdaptiveLayoutContext(
            size: CGSize(width: 800, height: 600), safeAreaInsets: EdgeInsets(),
            divisionRegions: [], occlusionRegions: [CGRect(x: 360, y: 0, width: 80, height: 48)]
        )
        XCTAssertEqual(layout.singleColumnBounds, CGRect(x: 0, y: 56, width: 800, height: 544))
        layout.divisionRegions = [CGRect(x: 350, y: 0, width: 20, height: 600)]
        XCTAssertEqual(layout.singleColumnBounds, CGRect(x: 0, y: 0, width: 338, height: 600))
        layout.occlusionRegions = [CGRect(x: 30, y: 0, width: 80, height: 48)]
        XCTAssertEqual(layout.singleColumnBounds, CGRect(x: 0, y: 56, width: 338, height: 544))
    }

    func testExpandingSecondaryCompactAnchorKeepsItWhenFoldedAgainWithoutDragging() {
        var position = AdaptiveScrollPosition()
        position.primary = "stats-summary"
        position.secondary = "stats-calendar"
        position.compact = "stats-overtime"
        position.transition(toExpanded: true, isSecondary: { $0.hasPrefix("stats-overtime") })
        XCTAssertEqual(position.primary, "stats-summary")
        XCTAssertEqual(position.secondary, "stats-overtime")
        position.transition(toExpanded: false, isSecondary: { _ in false })
        XCTAssertEqual(position.compact, "stats-overtime")
    }

    func testExpandingPrimaryCompactAnchorReplacesPreviousSecondaryPreference() {
        var position = AdaptiveScrollPosition()
        position.primary = "calendar-grid"
        position.secondary = "calendar-footer"
        position.lastWidePaneWasSecondary = true
        position.compact = "calendar-month"
        position.transition(toExpanded: true, isSecondary: { $0 == "calendar-footer" })
        position.transition(toExpanded: false, isSecondary: { _ in false })
        XCTAssertEqual(position.compact, "calendar-month")
    }

    func testHomeCollapsesToLastUsedSharedActionAnchor() {
        var position = AdaptiveScrollPosition()
        position.primary = "home-earnings"
        position.secondary = "home-moyu"
        position.lastWidePaneWasSecondary = true
        position.transition(toExpanded: false, isSecondary: { _ in false })
        XCTAssertEqual(position.compact, "home-moyu")
        position.transition(toExpanded: true, isSecondary: { $0 == "home-moyu" })
        XCTAssertEqual(position.primary, "home-earnings")
        XCTAssertEqual(position.secondary, "home-moyu")
    }

    func testExpandedOnlyHomeActionFallsBackToExistingCompactContent() {
        var position = AdaptiveScrollPosition()
        position.primary = "home-progress"
        position.secondary = "home-actions"
        position.lastWidePaneWasSecondary = true
        position.transition(toExpanded: false, isSecondary: { _ in false }, expandedOnlyAnchors: ["home-actions"])
        XCTAssertEqual(position.compact, "home-progress")
    }

    func testDynamicWishAnchorReturnsToOtherPaneAndSurvivesAnotherFold() {
        var position = AdaptiveScrollPosition()
        position.primary = "wish-focused"
        position.compact = "wish-other-BBD7"
        position.transition(toExpanded: true, isSecondary: { $0.hasPrefix("wish-other-") })
        position.transition(toExpanded: false, isSecondary: { _ in false })
        XCTAssertEqual(position.compact, "wish-other-BBD7")
        position.secondary = nil
        position.transition(toExpanded: false, isSecondary: { _ in false })
        XCTAssertEqual(position.compact, "wish-focused")
    }

    func testHiddenBarClearsContentInsetAndOffset() {
        for safeArea: CGFloat in [0, 8, 34, 50] {
            let occupancy = TabChromeLayout.occupancy(barVisible: false, bottomSafeArea: safeArea)
            XCTAssertEqual(occupancy.contentBottomInset, 0)
            XCTAssertEqual(occupancy.barBottomOffset, 0)
        }
    }

    func testVisibleBarUsesBarHeightAndSafeArea() {
        let barHeight = TabChromeLayout.defaultBarHeight
        var previousInsetByGrowingSafeArea: CGFloat?

        for safeArea: CGFloat in [0, 8, 34, 50] {
            let occupancy = TabChromeLayout.occupancy(
                barVisible: true,
                bottomSafeArea: safeArea,
                barHeight: barHeight
            )

            XCTAssertGreaterThanOrEqual(
                occupancy.contentBottomInset,
                barHeight,
                "Visible-bar content inset must clear the bar at safe-area \(safeArea)"
            )
            XCTAssertGreaterThanOrEqual(occupancy.barBottomOffset, 0)
            XCTAssertGreaterThanOrEqual(
                occupancy.barBottomOffset,
                safeArea,
                "Bar bottom must stay at or above the safe-area bottom; negative offset would clip it"
            )
            XCTAssertEqual(occupancy.contentBottomInset, barHeight + occupancy.barBottomOffset)

            if safeArea > TabChromeLayout.minimumLift, let previous = previousInsetByGrowingSafeArea {
                XCTAssertGreaterThan(
                    occupancy.contentBottomInset,
                    previous,
                    "Content inset must grow with the home-indicator / mirrored safe-area"
                )
            }
            previousInsetByGrowingSafeArea = occupancy.contentBottomInset
        }

        let atZero = TabChromeLayout.occupancy(barVisible: true, bottomSafeArea: 0, barHeight: barHeight)
        let atHomeIndicator = TabChromeLayout.occupancy(barVisible: true, bottomSafeArea: 34, barHeight: barHeight)
        let atMirrored = TabChromeLayout.occupancy(barVisible: true, bottomSafeArea: 50, barHeight: barHeight)
        XCTAssertGreaterThan(atHomeIndicator.contentBottomInset, atZero.contentBottomInset)
        XCTAssertGreaterThan(atMirrored.contentBottomInset, atZero.contentBottomInset)
        XCTAssertNotEqual(atHomeIndicator, atZero)
        XCTAssertNotEqual(atMirrored, atZero)
    }

    func testSafeAreaRespectingPaddingDoesNotDoubleCountOrClip() {
        let barHeight = TabChromeLayout.defaultBarHeight
        let lift = TabChromeLayout.minimumLift

        let hidden = TabChromeLayout.occupancy(barVisible: false, bottomSafeArea: 34)
            .paddingInSafeAreaRespectingContainer(bottomSafeArea: 34)
        XCTAssertEqual(hidden.contentBottomInset, 0)
        XCTAssertEqual(hidden.barBottomOffset, 0)

        let noHomeIndicator = TabChromeLayout.occupancy(barVisible: true, bottomSafeArea: 0, barHeight: barHeight)
            .paddingInSafeAreaRespectingContainer(bottomSafeArea: 0)
        XCTAssertEqual(noHomeIndicator.contentBottomInset, barHeight + lift)
        XCTAssertEqual(noHomeIndicator.barBottomOffset, lift)

        for safeArea: CGFloat in [8, 34, 50] {
            let physical = TabChromeLayout.occupancy(
                barVisible: true,
                bottomSafeArea: safeArea,
                barHeight: barHeight
            )
            let padding = physical.paddingInSafeAreaRespectingContainer(bottomSafeArea: safeArea)
            XCTAssertGreaterThanOrEqual(padding.contentBottomInset, barHeight)
            XCTAssertGreaterThanOrEqual(padding.barBottomOffset, 0)
            XCTAssertEqual(padding.contentBottomInset, physical.contentBottomInset - safeArea)
            XCTAssertEqual(padding.barBottomOffset, physical.barBottomOffset - safeArea)
        }
    }

    func testTwoColumnDecisionUsesGeometrySizeWithoutCountingSafeAreaTwice() {
        let wide = AdaptiveLayoutContext(
            size: CGSize(width: 720, height: 680),
            safeAreaInsets: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20),
            divisionRegions: [],
            occlusionRegions: []
        )
        XCTAssertTrue(wide.hasRoomForTwoColumns)

        var boundary = wide
        boundary.size.width = 695
        XCTAssertFalse(boundary.hasRoomForTwoColumns, "The page margins and column gap must leave 320pt of content per pane")
        boundary.size.width = 696
        XCTAssertTrue(boundary.hasRoomForTwoColumns)

        var narrowed = wide
        narrowed.size.width = 660
        narrowed.safeAreaInsets = EdgeInsets(top: 0, leading: 60, bottom: 0, trailing: 20)
        XCTAssertFalse(narrowed.hasRoomForTwoColumns)

        let duo = AdaptiveLayoutContext(
            size: CGSize(width: 867, height: 635),
            safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84),
            divisionRegions: [CGRect(x: 455.5, y: 0, width: 40, height: 669)],
            occlusionRegions: []
        )
        XCTAssertTrue(duo.hasRoomForTwoColumns, "GeometryReader already excludes the side rail from its size")
        XCTAssertEqual(duo.singleColumnWidth, 443.5, "Single-column fallback must stop before the fold")

        var bookPose = wide
        bookPose.divisionRegions = [CGRect(x: 350, y: 0, width: 20, height: 680)]
        XCTAssertTrue(bookPose.hasRoomForTwoColumns)
        bookPose.divisionRegions = [CGRect(x: 340, y: 0, width: 20, height: 680)]
        XCTAssertFalse(bookPose.hasRoomForTwoColumns, "The fold and pane padding must leave 320pt of content on both sides")
        bookPose.divisionRegions = [CGRect(x: 310, y: 0, width: 50, height: 680)]
        XCTAssertFalse(bookPose.hasRoomForTwoColumns, "The hinge must leave 320pt on each side")
        XCTAssertEqual(bookPose.singleColumnWidth, 298)
    }

    func testDeskClockRequiresAnActualHorizontalFoldWithReachableControls() {
        var layout = AdaptiveLayoutContext(
            size: CGSize(width: 720, height: 600),
            safeAreaInsets: EdgeInsets(),
            divisionRegions: [CGRect(x: 0, y: 300, width: 720, height: 18)],
            occlusionRegions: []
        )
        XCTAssertTrue(layout.canShowDeskClock)

        layout.divisionRegions = [CGRect(x: 350, y: 0, width: 18, height: 600)]
        XCTAssertFalse(layout.canShowDeskClock, "Book pose must keep the page layout")

        layout.divisionRegions = [CGRect(x: 0, y: 520, width: 720, height: 18)]
        XCTAssertFalse(layout.canShowDeskClock, "A too-short control region cannot enter desk mode")
    }

    func testTopControlsClearOnlyOcclusionsInTheirOwnPane() {
        let layout = AdaptiveLayoutContext(
            size: CGSize(width: 800, height: 600),
            safeAreaInsets: EdgeInsets(),
            divisionRegions: [],
            occlusionRegions: [CGRect(x: 580, y: 0, width: 80, height: 48)]
        )
        XCTAssertEqual(layout.topControlClearance(in: CGRect(x: 0, y: 0, width: 400, height: 600)), 0)
        XCTAssertEqual(layout.topControlClearance(in: CGRect(x: 400, y: 0, width: 400, height: 600)), 56)

        var centeredOcclusion = layout
        centeredOcclusion.occlusionRegions = [CGRect(x: 360, y: 0, width: 80, height: 48)]
        XCTAssertEqual(centeredOcclusion.topControlClearance(in: CGRect(x: 0, y: 0, width: 800, height: 600)), 0)

        var lowerOcclusion = layout
        lowerOcclusion.occlusionRegions = [CGRect(x: 580, y: 180, width: 80, height: 48)]
        XCTAssertEqual(lowerOcclusion.topControlClearance(in: CGRect(x: 400, y: 0, width: 400, height: 600)), 0)
    }

    func testDeskClockDoesNotEnterWhenHeaderLeavesTooLittleRoomForTime() {
        var layout = AdaptiveLayoutContext(
            size: CGSize(width: 720, height: 600),
            safeAreaInsets: EdgeInsets(),
            divisionRegions: [CGRect(x: 0, y: 120, width: 720, height: 18)],
            occlusionRegions: []
        )
        XCTAssertFalse(layout.canShowDeskClock, "The top pane must fit the header, label and a readable time without entering the fold")
        layout.divisionRegions = [CGRect(x: 0, y: 160, width: 720, height: 18)]
        XCTAssertTrue(layout.canShowDeskClock)
    }

    func testDeskClockEntryAccountsForCameraClearanceBeforeTime() {
        var layout = AdaptiveLayoutContext(
            size: CGSize(width: 720, height: 600),
            safeAreaInsets: EdgeInsets(),
            divisionRegions: [CGRect(x: 0, y: 180, width: 720, height: 18)],
            occlusionRegions: []
        )
        XCTAssertTrue(layout.canShowDeskClock)
        layout.occlusionRegions = [CGRect(x: 600, y: 0, width: 80, height: 48)]
        XCTAssertFalse(layout.canShowDeskClock, "Moving the header below the camera must reduce the space available for the time")
        layout.divisionRegions = [CGRect(x: 0, y: 240, width: 720, height: 18)]
        XCTAssertTrue(layout.canShowDeskClock, "A roomy upper pane should still enter desk mode with the camera enabled")
    }

    func testDeskClockStatePriorityAndRestingFallback() {
        XCTAssertEqual(DeskClockMode.select(status: .working, hasFocus: false, hasOvertime: false, hasNextWork: false), .offWork)
        XCTAssertEqual(DeskClockMode.select(status: .lunchBreak, hasFocus: false, hasOvertime: false, hasNextWork: false), .offWork)
        XCTAssertEqual(DeskClockMode.select(status: .afterWork, hasFocus: false, hasOvertime: false, hasNextWork: true), .nextWork)
        XCTAssertEqual(DeskClockMode.select(status: .restDay, hasFocus: false, hasOvertime: false, hasNextWork: false), .resting)
        XCTAssertEqual(DeskClockMode.select(status: .afterWork, hasFocus: false, hasOvertime: true, hasNextWork: true), .overtime)
        XCTAssertEqual(DeskClockMode.select(status: .working, hasFocus: true, hasOvertime: true, hasNextWork: false), .focus)
    }
}
