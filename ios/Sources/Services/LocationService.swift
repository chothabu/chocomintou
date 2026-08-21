import CoreLocation
import Foundation

/// 現在地の取得。権限は「アプリ使用中のみ」で足りる（設計 §50）。常時取得は使わない。
@MainActor
@Observable
final class LocationService {
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isResolving = false

    private let manager = CLLocationManager()
    private var updateTask: Task<Void, Never>?

    /// 位置が取れないときの表示中心。地図が真っ白にならないようにするためだけの値。
    static let fallbackCoordinate = CLLocationCoordinate2D(latitude: 35.6595, longitude: 139.7005)

    init() {
        authorizationStatus = manager.authorizationStatus
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// 現在地が未取得ならフォールバックを返す。
    var effectiveCoordinate: CLLocationCoordinate2D {
        coordinate ?? Self.fallbackCoordinate
    }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
        authorizationStatus = manager.authorizationStatus
    }

    /// 現在地の監視を始める。delegate ではなく iOS 17 の async シーケンスを使う。
    func start() {
        guard updateTask == nil else { return }
        isResolving = coordinate == nil
        updateTask = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.default) {
                    guard let self else { return }
                    self.authorizationStatus = self.manager.authorizationStatus
                    if let location = update.location {
                        self.coordinate = location.coordinate
                        self.isResolving = false
                    }
                    // 拒否の判定 API は iOS 18 以降。17 では manager の状態で代替する。
                    if #available(iOS 18.0, *) {
                        if update.authorizationDenied || update.authorizationDeniedGlobally {
                            self.isResolving = false
                            break
                        }
                    } else if self.isDenied {
                        self.isResolving = false
                        break
                    }
                }
            } catch {
                self?.isResolving = false
            }
            self?.updateTask = nil
        }
    }

    func stop() {
        updateTask?.cancel()
        updateTask = nil
        isResolving = false
    }
}
