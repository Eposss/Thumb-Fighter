import SwiftUI

@main
struct ThumbFighterApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
