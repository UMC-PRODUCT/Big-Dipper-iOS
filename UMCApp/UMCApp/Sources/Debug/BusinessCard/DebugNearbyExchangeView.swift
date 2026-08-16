//
//  DebugNearbyExchangeView.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
import CoreNearbyExchange
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 시안 12654:32255(레이더) · 12654:32621(목록)의 **임시 뷰**.
///
/// **배치만 시안을 따른다.** 색·타이포·글래스는 시스템 값이다. 목적은 요소가 제자리에
/// 오는지와 그 아래 기능(MPC 발견 + NI 거리)이 실제로 도는지 보는 것이지 픽셀을 맞추는 게
/// 아니다. 제품 화면 승격은 별도 작업이다.
///
/// 시안의 「Wi-Fi Aware 탐색」 문구는 쓰지 않는다 — 실제 구현이 MPC 라 틀린 말이 된다.
/// 기술명을 빼는 편이 카피로도 낫다(사용자에게 `Wi-Fi Aware` 는 의미 없는 단어다).
struct DebugNearbyExchangeView: View {

    // MARK: - Property

    let viewModel: BusinessCardDebugViewModel

    private enum Constants {
        static let horizontalPadding: CGFloat = 16
        static let radarSize: CGFloat = 364
        static let radarRings: [CGFloat] = [364, 300, 230, 160]
        static let logoSize: CGFloat = 80
        static let captionSpacing: CGFloat = 30
        static let listSpacing: CGFloat = 8

        static let rowRadius: CGFloat = 34
        static let rowPadding: CGFloat = 16
        static let rowSpacing: CGFloat = 16
        static let avatarSize: CGFloat = 48
        static let rowTextSpacing: CGFloat = 4
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.peers.isEmpty {
                searchingState
            } else {
                peerList
            }

            diagnostics

            stopButton
        }
        .navigationTitle("명함 교환")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .task {
            guard !viewModel.isExchanging else { return }
            await viewModel.toggleExchange()
        }
    }

    // MARK: - View Component

    /// 시안 12654:32255 — 발견 전 상태.
    private var searchingState: some View {
        VStack(spacing: 0) {
            statusChip
                .padding(.top, 11)

            radar
                .padding(.top, 40)

            VStack(spacing: 8) {
                Text("주변 UMC 멤버를 찾는 중…")
                    .font(.title3.bold())

                Text("상대방도 「명함 교환」을 누르면\n여기에 나타나요")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, Constants.captionSpacing)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .foregroundStyle(Color.accentColor)
            Text("주변 탐색")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: .capsule)
        .overlay(Capsule().stroke(Color(.separator), lineWidth: 0.5))
    }

    private var radar: some View {
        ZStack {
            ForEach(Constants.radarRings, id: \.self) { size in
                Circle()
                    .stroke(Color.accentColor.opacity(0.14), lineWidth: 1)
                    .background(Circle().fill(Color.accentColor.opacity(0.02)))
                    .frame(width: size, height: size)
            }

            Image.umcDefaultProfile
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: Constants.logoSize, height: Constants.logoSize)
                .clipShape(.circle)
        }
        .frame(width: Constants.radarSize, height: Constants.radarSize)
        .accessibilityLabel("주변 멤버를 찾는 중")
    }

    /// 시안 12654:32621 — 발견 목록.
    private var peerList: some View {
        ScrollView {
            LazyVStack(spacing: Constants.listSpacing) {
                ForEach(viewModel.peers, id: \.id) { peer in
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            Task { await viewModel.send(to: peer) }
                        } label: {
                            peerRow(peer)
                        }
                        .buttonStyle(.plain)

                        if let state = viewModel.sendStates[peer.id] {
                            sendStatusLabel(state)
                        }
                    }
                }
            }
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.top, Constants.rowPadding)
        }
    }

    /// 시안 `item_명함`(12654:32620) — 370×80, radius 34, padding 16.
    private func peerRow(_ peer: DiscoveredPeer) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: Constants.rowSpacing) {
                avatar(peer)

                VStack(alignment: .leading, spacing: Constants.rowTextSpacing) {
                    Text(peer.displayName ?? peer.id)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle(peer))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    // 시안에 없는 검증용 표시. 같은 사람이 두 행으로 보일 때 어느 쪽이
                    // 살아 있는 세션인지 이것 없이는 구분할 수 없다 (식별자는 실행마다 바뀐다).
                    HStack(spacing: 4) {
                        Circle()
                            .fill(viewModel.connectedPeerIDs.contains(peer.id) ? .green : .orange)
                            .frame(width: 6, height: 6)
                        Text(peer.id)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: Constants.rowSpacing)

            distanceBlock(peer)
        }
        .padding(Constants.rowPadding)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: Constants.rowRadius)
        )
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
        .contentShape(.rect)
    }

    /// 시안 우측 — 신호 막대와 「2.1m」. **둘 다 NI 거리 하나에서 파생된다.**
    private func distanceBlock(_ peer: DiscoveredPeer) -> some View {
        VStack(alignment: .trailing, spacing: Constants.rowTextSpacing) {
            // 거리를 모르면 막대도 그리지 않는다. 꽉 찬 막대를 남기면 신호가 강한 것처럼
            // 보이는데, 눈앞의 사람을 가려내는 게 이 표시의 목적이라 그 오해가 치명적이다.
            if let meters = peer.distanceMeters {
                Image(systemName: signalSymbol(for: meters))
                    .font(.system(size: 15))
                Text(String(format: "%.1fm", meters))
                    .font(.footnote.monospacedDigit())
            } else {
                Text("—")
                    .font(.footnote.monospacedDigit())
            }
        }
        .foregroundStyle(peer.distanceMeters == nil ? Color.secondary : Color.accentColor)
    }

    /// 탭 결과를 화면에 남긴다. 이게 없으면 실패인지 무반응인지 구분할 수 없다.
    @ViewBuilder
    private func sendStatusLabel(_ state: BusinessCardDebugViewModel.SendState) -> some View {
        switch state {
        case .sending:
            Label("전송 중…", systemImage: "arrow.up.circle")
                .font(.caption).foregroundStyle(.secondary)
        case .sent:
            Label("전송 완료 — 명함첩 확인", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        case .failed(let message):
            VStack(alignment: .leading, spacing: 2) {
                Label("전송 실패", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption.bold()).foregroundStyle(.red)
                Text(message)
                    .font(.caption2).monospaced()
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        }

    private func avatar(_ peer: DiscoveredPeer) -> some View {
        Group {
            if let avatarURL = peer.avatarURL, let url = URL(string: avatarURL) {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Image.umcDefaultProfile.resizable().scaledToFill()
                }
            } else {
                Image.umcDefaultProfile.resizable().scaledToFill()
            }
        }
        .frame(width: Constants.avatarSize, height: Constants.avatarSize)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    /// 시안에 없는 진단 영역. MPC 는 초대·수락·연결이 델리게이트로 흩어져 있어
    /// 이것 없이는 "탭했는데 아무 일도 안 일어남"의 원인을 볼 수 없다.
    private var diagnostics: some View {
        // **이 한 줄이 없으면 아래 값들이 영원히 첫 값에 머문다.** `connectedPeerIDs` 와
        // `transportLog` 는 `@Observable` 이 아닌 transport 를 읽는 계산 프로퍼티라
        // SwiftUI 가 변화를 감지하지 못한다. 관측되는 tick 을 읽어 재평가를 유발한다.
        let tick = viewModel.diagnosticsTick

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("연결됨 \(viewModel.connectedPeerIDs.count) / 발견 \(viewModel.peers.count)")
                    .font(.caption.bold())
                Spacer()
                // 폴링이 살아 있는지 보이게 한다 — 멈춰 있으면 아래 값은 못 믿는다.
                Text("·\(tick % 10)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }

            if let error = viewModel.transportError {
                Text(error)
                    .font(.caption2).monospaced()
                    .foregroundStyle(.red)
                    .textSelection(.enabled)
            }

            ForEach(Array(viewModel.transportLog.prefix(10).enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.caption2).monospaced()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.bottom, 8)
    }

    private var stopButton: some View {
        Button(role: .destructive) {
            Task { await viewModel.toggleExchange() }
        } label: {
            Text("교환 중지").frame(maxWidth: .infinity)
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .padding(.horizontal, Constants.horizontalPadding)
        .padding(.bottom, Constants.rowPadding)
    }

    // MARK: - Function

    private func subtitle(_ peer: DiscoveredPeer) -> String {
        let part = peer.part.flatMap { UMCPartType(apiValue: $0)?.name } ?? peer.part
        return [part, peer.generation.map { "\($0)기" }]
            .compactMap { $0 }
            .joined(separator: " ・")
    }

    /// 거리를 막대 칸수로 옮긴다.
    private func signalSymbol(for meters: Double) -> String {
        switch meters {
        case ..<1:  return "cellularbars"
        case ..<3:  return "chart.bar.fill"
        default:    return "chart.bar"
        }
    }
}
#endif
