//
//  DebugExchangeView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreNearbyExchange
import SwiftUI
import UMCFoundation

/// 명함 카드의 「명함 교환」 버튼이 여는 화면 (시안 명함교환 자리).
///
/// 시뮬레이터에서는 `MockNearbyTransport`가 주입돼 즉시 이벤트가 흐르고, 실기기에서는
/// Wi-Fi Aware가 붙는다. 페어링된 기기가 없으면 `notPaired`가 뜨는 게 정상이다.
struct DebugExchangeView: View {

    // MARK: - Property

    let viewModel: BusinessCardDebugViewModel

    @State private var transportChoice = NearbyTransportChoice.current

    // MARK: - Body

    var body: some View {
        List {
            Section {
                Picker("전송 방식", selection: $transportChoice) {
                    ForEach(NearbyTransportChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: transportChoice) { _, newValue in
                    NearbyTransportChoice.select(newValue)
                }

                Text(transportChoice.caveat)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if transportChoice != viewModel.activeChoice {
                    Label("앱을 다시 켜야 적용된다", systemImage: "arrow.clockwise.circle.fill")
                        .font(.footnote.bold())
                        .foregroundStyle(.orange)
                }

                labeled("주입된 transport", viewModel.transportTypeName)
                labeled("Wi-Fi Aware 지원", "\(WiFiAwareTransport.isSupported)")

                // "주변에 아무도 없음"과 "브라우저가 실패해 스트림이 닫힘"은 화면에서
                // 똑같이 peers: 0 으로 보인다. 두 상태를 가르는 값들이다.
                VStack(alignment: .leading, spacing: 4) {
                    Text("페어링된 기기 \(viewModel.pairedDeviceNames.count)대")
                        .font(.callout)
                    ForEach(Array(viewModel.pairedDeviceNames.enumerated()), id: \.offset) { _, name in
                        Text("· \(name)").font(.caption).foregroundStyle(.secondary)
                    }
                    if viewModel.pairedDeviceNames.isEmpty {
                        Text("없음 — 「기기 페어링」을 먼저 해야 한다")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }

                Button("페어링 목록 새로고침") {
                    Task { await viewModel.reloadPairedDevices() }
                }

                if let error = viewModel.transportError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("transport 실패").font(.footnote.bold()).foregroundStyle(.red)
                        Text(error)
                            .font(.caption2).monospaced()
                            .textSelection(.enabled)
                    }
                }

                #if canImport(DeviceDiscoveryUI)
                NavigationLink {
                    WiFiAwarePairingView()
                } label: {
                    Label("기기 페어링", systemImage: "dot.radiowaves.left.and.right")
                }
                #endif
            } header: {
                Text("전송 계층")
            } footer: {
                Text("Wi-Fi Aware는 페어링된 기기끼리만 연결된다. 먼저 「기기 페어링」으로 상대를 등록해야 한다.")
            }

            Section {
                NavigationLink {
                    DebugNearbyExchangeView(viewModel: viewModel)
                } label: {
                    Label("시안 배치로 보기", systemImage: "rectangle.on.rectangle")
                }
            } header: {
                Text("임시 뷰 — 시안 12654:32255 · 32621")
            } footer: {
                Text("배치만 시안을 따른다. 색·타이포는 시스템 값이다. 진입하면 교환 세션이 자동 시작된다.")
            }

            Section {
                HStack {
                    Button(viewModel.isExchanging ? "세션 중지" : "교환 세션 시작") {
                        Task { await viewModel.toggleExchange() }
                    }
                    Spacer()
                    Text("peers: \(viewModel.peers.count)")
                        .foregroundStyle(.secondary)
                }

                ForEach(viewModel.peers, id: \.id) { peer in
                    Button {
                        Task { await viewModel.send(to: peer) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(peer.displayName ?? peer.id)
                                Text(
                                    [peer.part, peer.generation.map { "\($0)기" }]
                                        .compactMap { $0 }.joined(separator: " · ")
                                )
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            // 시안 12654:32621 의 「2.1m」 자리. UWB 미탑재·범위 밖은 빈다.
                            Text(peer.distanceMeters.map { String(format: "%.2fm", $0) } ?? "—")
                                .font(.callout.monospacedDigit())
                                .foregroundStyle(peer.distanceMeters == nil ? .tertiary : .primary)
                        }
                    }
                }
            } header: {
                Text("교환 세션 — ExchangeCardsUseCase")
            }

            Section {
                if viewModel.eventLog.isEmpty {
                    Text("이벤트 없음").foregroundStyle(.secondary)
                } else {
                    ForEach(Array(viewModel.eventLog.enumerated()), id: \.offset) { _, line in
                        Text(line).font(.caption).monospaced()
                    }
                }
            } header: {
                Text("이벤트 로그")
            }
        }
        .navigationTitle("명함 교환")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Function

    private func labeled(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key).foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.callout)
    }
}
#endif
