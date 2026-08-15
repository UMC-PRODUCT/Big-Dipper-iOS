//
//  WiFiAwarePairingView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG && canImport(DeviceDiscoveryUI)
import CoreNearbyExchange
import DeviceDiscoveryUI
import SwiftUI
import WiFiAware

/// Wi-Fi Aware 페어링 진입점 (검증 화면 전용).
///
/// `WiFiAwareTransport`는 페어링된 기기가 없으면 `notPaired`를 던진다. 페어링 자체는
/// 시스템 UI(DeviceDiscoveryUI)로만 할 수 있고 앱이 대신할 수 없다 — 그래서 교환을
/// 시도하려면 이 화면을 먼저 거쳐야 한다.
///
/// 두 기기의 역할이 다르다:
/// - **찾는 쪽(DevicePicker)**: 주변 기기 목록에서 상대를 고른다
/// - **기다리는 쪽(DevicePairingView)**: 상대가 나를 찾도록 대기한다
///
/// 한 기기가 Picker, 다른 기기가 PairingView를 띄워야 페어링이 성립한다.
struct WiFiAwarePairingView: View {

    // MARK: - Property

    @State private var pairedNames: [String] = []
    @State private var errorMessage: String?

    // MARK: - Body

    var body: some View {
        List {
            Section {
                DevicePicker(
                    .wifiAware(.connecting(to: .userSpecifiedDevices, from: .umcCardSubscribable))
                ) { endpoint in
                    let device = endpoint.device
                    let name = device.name ?? device.pairingInfo?.pairingName ?? "\(device.id)"
                    pairedNames.append(name)
                } label: {
                    Label("주변 기기 찾기", systemImage: "magnifyingglass")
                } fallback: {
                    Label("이 기기에서 사용할 수 없음", systemImage: "xmark.circle")
                }
            } header: {
                Text("찾는 쪽")
            } footer: {
                Text("상대 기기가 아래 「기다리는 쪽」을 띄운 상태여야 목록에 뜬다.")
            }

            Section {
                DevicePairingView(
                    .wifiAware(.connecting(to: .umcCardPublishable, from: .userSpecifiedDevices))
                ) {
                    Label("페어링 요청 기다리기", systemImage: "dot.radiowaves.left.and.right")
                } fallback: {
                    Label("이 기기에서 사용할 수 없음", systemImage: "xmark.circle")
                }
            } header: {
                Text("기다리는 쪽")
            }

            Section {
                if pairedNames.isEmpty {
                    Text("이 화면에서 페어링한 기기 없음")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pairedNames, id: \.self) { Text($0) }
                }
                Button("현재 페어링된 기기 조회") {
                    Task { await refreshPairedDevices() }
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            } header: {
                Text("페어링 결과")
            } footer: {
                Text("여기에 기기가 하나라도 있어야 교환 세션이 notPaired 없이 시작된다.")
            }
        }
        .navigationTitle("Wi-Fi Aware 페어링")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refreshPairedDevices() }
    }

    // MARK: - Function

    private func refreshPairedDevices() async {
        do {
            for try await devices in WAPairedDevice.allDevices {
                pairedNames = devices.values.map { device in
                    device.name ?? device.pairingInfo?.pairingName ?? "\(device.id)"
                }
                errorMessage = nil
                return
            }
        } catch {
            errorMessage = "조회 실패: \(error.localizedDescription)"
        }
    }
}
#endif
