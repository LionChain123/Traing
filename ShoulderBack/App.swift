import SwiftUI

@main
struct ShoulderBackApp: App {
    @StateObject private var store = TrainingStore()
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store).tint(Palette.lime)
                .preferredColorScheme(.dark)
        }
    }
}

enum Palette {
    static let lime = Color(red: 0.79, green: 0.96, blue: 0.35)
    static let background = Color(red: 0.055, green: 0.065, blue: 0.065)
    static let panel = Color(red: 0.10, green: 0.12, blue: 0.12)
}

extension View {
    func trainingCard() -> some View {
        padding(20).background(Palette.panel, in: RoundedRectangle(cornerRadius: 24))
    }
}
