//
//  DebugExchangeView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreNearbyExchange
import SwiftUI

/// 명함 카드의 「명함 교환」 버튼이 여는 화면 (시안 명함교환 자리).
///
/// 시뮬레이터에서는 `MockNearbyTransport`가 주입돼 즉시 이벤트가 흐르고, 실기기에서는
/// Wi-Fi Aware가 붙는다. 페어링된 기기가 없으면 `notPaired`가 뜨는 게 정상이다.
struct DebugExchangeView: View {

    // MARK: - Property

    let viewModel: BusinessCardDebugViewModel

    // MARK: - Body

    var body: some View {
        List {
            Section {
                labeled("Wi-Fi Aware 지원", "\(WiFiAwareTransport.isSupported)")
                labeled("주입된 transport", viewModel.transportTypeName)

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
                        VStack(alignment: .leading) {
                            Text(peer.displayName ?? peer.id)
                            Text("탭하면 내 명함 전송")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
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
