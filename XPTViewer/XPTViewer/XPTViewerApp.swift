import SwiftUI

@main
struct XPTViewerApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: XPTDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            SidebarCommands()
        }
    }
}
