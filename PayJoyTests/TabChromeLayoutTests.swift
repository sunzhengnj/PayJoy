import XCTest
@testable import PayJoy

final class TabChromeLayoutTests: XCTestCase {
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
}
