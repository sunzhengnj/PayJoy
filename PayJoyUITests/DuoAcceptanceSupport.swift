import XCTest

@MainActor
extension XCTestCase {
    func requirePoseHost() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["PAYJOY_DUO_POSE_HOST"] == "1",
                          "Use PayJoyPoseUITests with scripts/qa/run_duo_pose_tests.py")
    }


    @discardableResult
    func requestPose(_ action: String, readsLayout: Bool = false) throws -> String? {
        let id = UUID().uuidString
        let requestURL = FileManager.default.temporaryDirectory.appendingPathComponent("payjoy-duo-pose-\(id).json")
        let ackURL = requestURL.appendingPathExtension("ack")
        defer {
            try? FileManager.default.removeItem(at: requestURL)
            try? FileManager.default.removeItem(at: ackURL)
        }
        let data = try JSONSerialization.data(withJSONObject: ["id": id, "action": action, "ack": ackURL.path,
            "readsLayout": readsLayout, "udid": ProcessInfo.processInfo.environment["SIMULATOR_UDID"] ?? ""], options: [.sortedKeys])
        try data.write(to: requestURL, options: .atomic)
        let marker = "PAYJOY_DUO_POSE_REQUEST \(requestURL.path)\n"
        FileHandle.standardOutput.write(Data(marker.utf8))
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            FileManager.default.fileExists(atPath: ackURL.path)
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 35), .completed, "Host did not confirm \(action)")
        let ack = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: ackURL)) as? [String: String])
        XCTAssertEqual(ack["id"], id)
        XCTAssertEqual(ack["action"], action)
        return ack["axis"]
    }


    func attachScreenshot(_ name: String) {
        for (index, screen) in XCUIScreen.screens.enumerated() {
            let screenshot = screen.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "\(name)-display\(index)-\(Int(screenshot.image.size.width))x\(Int(screenshot.image.size.height))"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }}
