// winmap: one line per normal window, "<window-id> <pid> <on-screen 0|1> <x> <y> <w> <h>".
//
// Why this exists: every container runs the same vendor binary, so they share one bundle id
// and one app name, and JankyBorders' app-name filters cannot tell them apart. Window ids can,
// via `borders apply-to=<id>`. CGWindowList is used instead of the Accessibility API because
// the Claude processes stop answering Accessibility queries while they are busy, which is
// exactly when their windows are on screen. Needs no Screen Recording permission: ids, owner
// pids and bounds are returned without it (only window titles are withheld).
// Layer 0 only: menus, the Dock, overlays and status items live on other layers.
import CoreGraphics
import Foundation

guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
    FileHandle.standardError.write("winmap: CGWindowListCopyWindowInfo returned nothing\n".data(using: .utf8)!)
    exit(1)
}
for w in list {
    guard (w[kCGWindowLayer as String] as? Int) == 0,
          let id = w[kCGWindowNumber as String] as? Int,
          let pid = w[kCGWindowOwnerPID as String] as? Int,
          let b = w[kCGWindowBounds as String] as? [String: Any] else { continue }
    let onscreen = (w[kCGWindowIsOnscreen as String] as? Bool) == true ? 1 : 0
    let n = { (k: String) -> Int in Int((b[k] as? Double) ?? Double((b[k] as? Int) ?? 0)) }
    print(id, pid, onscreen, n("X"), n("Y"), n("Width"), n("Height"))
}
