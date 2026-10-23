import AppKit
import ApplicationServices

let allowed = ["Open", "Partially Open", "Closed", "Rotate Right"]
guard CommandLine.arguments.count == 3, allowed.contains(CommandLine.arguments[1]),
      let pid = pid_t(CommandLine.arguments[2]), pid > 0 else {
    fputs("Expected a supported pose action and the Device Hub PID.\n", stderr)
    exit(2)
}
let action = CommandLine.arguments[1]
let root = AXUIElementCreateApplication(pid)

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
    var value: CFTypeRef?
    AXUIElementCopyAttributeValue(element, name as CFString, &value)
    return value
}

func button(_ element: AXUIElement, depth: Int = 0) -> AXUIElement? {
    guard depth < 14 else { return nil }
    if attribute(element, kAXRoleAttribute) as? String == kAXButtonRole,
       attribute(element, kAXDescriptionAttribute) as? String == action { return element }
    for child in attribute(element, kAXChildrenAttribute) as? [AXUIElement] ?? [] {
        if let found = button(child, depth: depth + 1) { return found }
    }
    return nil
}

NSRunningApplication(processIdentifier: pid)?.activate(options: [.activateAllWindows])
if let window = (attribute(root, kAXWindowsAttribute) as? [AXUIElement])?.first {
    AXUIElementPerformAction(window, kAXRaiseAction as CFString)
}
Thread.sleep(forTimeInterval: 1)
guard let control = button(root) else {
    fputs("Device Hub pose button unavailable (pid \(pid)).\n", stderr)
    exit(3)
}
let result = AXUIElementPerformAction(control, kAXPressAction as CFString)
guard result == .success else {
    fputs("Device Hub rejected pose action: \(result.rawValue).\n", stderr)
    exit(3)
}
let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
guard let window = windows.first(where: {
    ($0[kCGWindowOwnerPID as String] as? Int) == Int(pid)
        && ($0[kCGWindowLayer as String] as? Int) == 0
}), let windowID = window[kCGWindowNumber as String] as? Int else { exit(4) }
let output = try JSONSerialization.data(withJSONObject: ["action": action, "windowID": windowID], options: [.sortedKeys])
print(String(decoding: output, as: UTF8.self))
