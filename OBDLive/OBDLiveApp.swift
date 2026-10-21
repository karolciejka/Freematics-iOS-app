import SwiftUI

@main
struct OBDLiveApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .preferredColorScheme(.light)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        ZStack {
            DS.bg.ignoresSafeArea()
            switch model.screen {
            case .connect: ConnectView()
            case .app: AppShellView()
            }
        }
        .foregroundStyle(DS.text)
        .font(DS.body(15))
    }
}
