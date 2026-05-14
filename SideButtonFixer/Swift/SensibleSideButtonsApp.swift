// SensibleSideButtons — Swift rewrite
// Copyright (C) 2018 Alexei Baboulevitch, 2026 contributors
// GPLv2 — see LICENSE

import Cocoa
import SwiftUI

@main
struct SensibleSideButtonsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}
