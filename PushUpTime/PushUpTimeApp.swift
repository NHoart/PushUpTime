import SwiftUI

@main
struct PushUpTimeApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .onOpenURL { url in
                    model.handleIncomingURL(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    model.consumePendingChallenge()
                }
        }
    }
}
