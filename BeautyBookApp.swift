import SwiftUI

@main
struct BeautyBookApp: App {
    var body: some Scene {
        WindowGroup {
            TabBarView()
                .preferredColorScheme(.dark)
        }
    }
}