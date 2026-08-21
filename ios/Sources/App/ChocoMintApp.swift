import SwiftData
import SwiftUI

@main
struct ChocoMintApp: App {
    @State private var session = SessionStore(services: .make())
    @State private var location = LocationService()

    /// 直近データのキャッシュ。ネットが無くても前回の内容を出せるようにする（設計 §49）。
    private let modelContainer: ModelContainer = {
        do {
            return try ModelContainer(for: CachedPayload.self)
        } catch {
            // キャッシュは無くても動く。壊れていたらメモリのみで続行する。
            return try! ModelContainer(
                for: CachedPayload.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(location)
                .tint(Palette.mint)
        }
        .modelContainer(modelContainer)
    }
}
