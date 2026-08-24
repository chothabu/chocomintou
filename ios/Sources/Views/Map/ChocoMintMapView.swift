import MapKit
import SwiftUI

/// チョコミントマップ（設計 §15-17）。
/// v1.0 で表示するのは「目撃実績のある店舗」だけ。取り扱いチェーンの候補ピンは出さない。
struct ChocoMintMapView: View {
    @Environment(SessionStore.self) private var session
    @Environment(LocationService.self) private var location

    @State private var model = MapViewModel()
    @State private var camera: MapCameraPosition = .automatic
    @State private var visibleRegion: MKCoordinateRegion?
    @State private var hasInitialized = false

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            ZStack(alignment: .top) {
                map

                VStack(spacing: 8) {
                    if model.needsResearch {
                        Button {
                            Task { await searchVisibleArea() }
                        } label: {
                            Label("このエリアで検索", systemImage: "arrow.clockwise")
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                        }
                        .background(.regularMaterial, in: Capsule())
                        .shadow(radius: 3, y: 1)
                    }

                    if let message = model.errorMessage {
                        Text(message)
                            .font(.caption)
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.2), value: model.needsResearch)
            }
            .safeAreaInset(edge: .bottom) { bottomBar }
            .navigationTitle("マップ")
            .navigationBarTitleDisplayMode(.inline)
            .appNavigationDestinations()
            .task {
                guard !hasInitialized else { return }
                hasInitialized = true
                let center = location.effectiveCoordinate
                camera = .region(MKCoordinateRegion(
                    center: center, latitudinalMeters: 2000, longitudinalMeters: 2000
                ))
                await model.search(services: session.services, center: center, radiusMeters: 1500)
            }
            .onChange(of: model.onSaleOnly) { _, _ in
                Task { await searchVisibleArea() }
            }
        }
    }

    /// 選択中のピン。Map の selection は ID でやり取りする。
    private var selectionBinding: Binding<UUID?> {
        Binding<UUID?>(
            get: { model.selectedPin?.storeId },
            set: { newValue in
                model.selectedPin = model.pins.first { $0.storeId == newValue }
            }
        )
    }

    private var map: some View {
        Map(position: $camera, selection: selectionBinding) {
            UserAnnotation()

            // 目撃情報がまだ無い周辺のお店。報告先として選べるようにするためのもので、
            // 在庫の主張ではない。目撃ピンと取り違えられないよう小さく薄く出す。
            ForEach(model.reportableStores) { (store: StoreCandidate) in
                Annotation(store.name, coordinate: store.coordinate) {
                    reportableView(store)
                }
                .annotationTitles(.hidden)
            }

            ForEach(model.pins) { (pin: StorePin) in
                Annotation(pin.storeName, coordinate: pin.coordinate) {
                    pinView(pin)
                }
                .tag(pin.storeId)
                .annotationTitles(.hidden)
            }
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            visibleRegion = context.region
            model.cameraMoved(to: context.region.center)
        }
        .ignoresSafeArea(edges: .top)
    }

    private func pinView(_ pin: StorePin) -> some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(pin.freshness.color)
                    .frame(width: 32, height: 32)
                    .shadow(radius: 2, y: 1)
                Text(pin.items.count > 1 ? "\(pin.items.count)" : "🍦")
                    .font(.system(size: pin.items.count > 1 ? 14 : 15, weight: .bold))
                    .foregroundStyle(.white)
            }
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8))
                .foregroundStyle(pin.freshness.color)
                .offset(y: -4)
        }
        .scaleEffect(model.selectedPin?.storeId == pin.storeId ? 1.2 : 1)
        .animation(.spring(duration: 0.2), value: model.selectedPin?.storeId)
    }

    /// 目撃情報が無いお店。中身のない小さな丸にして、目撃ピンと明確に差をつける。
    private func reportableView(_ store: StoreCandidate) -> some View {
        Button {
            model.selectedReportable = store
        } label: {
            Circle()
                .fill(Color(.systemBackground))
                .overlay(Circle().stroke(Palette.mint.opacity(0.7), lineWidth: 2))
                .frame(width: 13, height: 13)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(store.name)。目撃情報はまだありません")
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
            if let store = model.selectedReportable {
                reportableCard(store)
            }
            if let pin = model.selectedPin {
                storeCard(pin)
            }

            HStack {
                Toggle(isOn: Binding(
                    get: { model.onSaleOnly },
                    set: { model.onSaleOnly = $0 }
                )) {
                    Text("販売中のみ")
                        .font(.subheadline)
                }
                .toggleStyle(.switch)
                .fixedSize()

                Spacer()

                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text(
                        model.reportableStores.isEmpty
                            ? "\(model.pins.count)店舗"
                            : "目撃 \(model.pins.count) / 周辺 \(model.reportableStores.count)"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }

    /// 目撃情報が無いお店を選んだときのカード。
    /// 在庫があるとは言わず、報告を促すだけにする。
    private func reportableCard(_ store: StoreCandidate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if let distance = store.distance {
                    Text(Formatters.distance(distance))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            Text("このお店の目撃情報はまだありません。")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("チョコミントを見つけたら、商品ページの「この商品を見つけた」から報告できます。")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack {
                Spacer()
                Button("閉じる") { model.selectedReportable = nil }
                    .font(.caption)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cardCorner))
        .padding(.horizontal, 12)
    }

    /// ピンをタップしたときのカード（設計 §17）。
    private func storeCard(_ pin: StorePin) -> some View {
        NavigationLink(value: AppRoute.store(pin.storeId)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(pin.storeName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    if let distance = pin.distanceM {
                        Text(Formatters.distance(distance))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                ForEach(pin.items.prefix(3)) { item in
                    HStack(spacing: 8) {
                        Circle().fill(item.freshness.color).frame(width: 7, height: 7)
                        Text(item.productName)
                            .font(.footnote)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text("最終目撃 \(Formatters.sightingTime(item.lastSeenAt))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                if pin.items.count > 3 {
                    Text("ほか \(pin.items.count - 3)件")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Metrics.cardCorner))
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func searchVisibleArea() async {
        let region = visibleRegion ?? MKCoordinateRegion(
            center: location.effectiveCoordinate,
            latitudinalMeters: 2000,
            longitudinalMeters: 2000
        )
        // 表示範囲の対角の半分を検索半径にする。
        let radius = CLLocation(
            latitude: region.center.latitude - region.span.latitudeDelta / 2,
            longitude: region.center.longitude
        ).distance(from: CLLocation(latitude: region.center.latitude, longitude: region.center.longitude))
        await model.search(
            services: session.services,
            center: region.center,
            radiusMeters: max(radius, 500)
        )
    }
}
