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

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 10) {
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
                    Text("\(model.pins.count)店舗")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.regularMaterial)
        }
    }

    /// ピンをタップしたときのカード（設計 §17）。
    private func storeCard(_ pin: StorePin) -> some View {
        NavigationLink(value: AppRoute.store(pin.storeId)) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(pin.storeName)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(Formatters.distance(pin.distanceM))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
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
