import Cocoa
import SwiftUI

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory) // This keeps it out of Cmd+Tab
app.run()
