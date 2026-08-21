import SwiftUI

/// 5 タブ構成（設計 §3）。
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LocationService.self) private var location

    var body: some View {
        @Bindable var session = session

        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
            SearchView()
                .tabItem { Label("探す", systemImage: "magnifyingglass") }
            ChocoMintMapView()
                .tabItem { Label("マップ", systemImage: "map") }
            NewsView()
                .tabItem { Label("ニュース", systemImage: "newspaper") }
            ProfileView()
                .tabItem { Label("マイページ", systemImage: "person.crop.circle") }
        }
        .task {
            await session.restore()
            location.start()
        }
        .sheet(isPresented: $session.isPresentingSignIn) {
            SignInView()
        }
    }
}
