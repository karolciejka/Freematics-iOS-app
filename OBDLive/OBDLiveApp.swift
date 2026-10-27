import SwiftUI

@main
struct OBDLiveApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage(SettingsKey.skin) private var skinRaw = Skin.simple.rawValue

    var body: some View {
        let skin = Skin(rawValue: skinRaw) ?? .simple
        let _ = DS.use(skin)
        ZStack {
            DS.bg.ignoresSafeArea()
            if skin.palette.textured { CarbonTexture().ignoresSafeArea() }
            switch model.screen {
            case .connect: ConnectView()
            case .app: AppShellView()
            }
        }
        .foregroundStyle(DS.text)
        .font(DS.body(15))
        // every view reads the active skin's tokens, so rebuild the tree when it changes
        .id(skin)
        .preferredColorScheme(skin.palette.dark ? .dark : .light)
    }
}
