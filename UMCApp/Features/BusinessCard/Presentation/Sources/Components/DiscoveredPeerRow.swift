//
//  DiscoveredPeerRow.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import SwiftUI
import CoreDesignSystem
import CoreNearbyExchange
import CoreUIComponents
import UMCFoundation

/// 교환 화면의 피어 한 줄 — 시안 `item_명함` (370×80, `Figma 12654:32620`).
struct DiscoveredPeerRow: View {

    // MARK: - Property

    let peer: DiscoveredPeer
    /// 이 상대에게 이미 내 명함을 보냈는지.
    var hasSent: Bool = false

    // MARK: - Constants

    private enum Constants {
        static let unknownName = "이름 없는 멤버"
        static let signalImage = "cellularbars"
        static let sentTitle = "보냈어요"
        static let sentImage = "checkmark.circle.fill"
        /// 파트와 기수를 잇는 구분자. 시안 표기 `iOS ・10기`.
        static let separator = " ・"
    }

    private enum Metrics {
        static let height: CGFloat = 80
        static let cornerRadius: CGFloat = 34
        static let padding: CGFloat = 16
        static let avatarSize: CGFloat = 48
        static let contentSpacing: CGFloat = 16
        static let textSpacing: CGFloat = 4
        static let signalSize: CGFloat = 15
        /// 시안 그림자 0 2 8 rgba(0,0,0,0.1). CSS 흐림 반경은 SwiftUI 의 약 두 배다.
        static let shadowRadius: CGFloat = 4
        static let shadowY: CGFloat = 2
        static let shadowOpacity: Double = 0.1
    }

    // MARK: - Computed Property

    /// MPC 는 광고 정보로 이름을 채우지만 채널이 못 주면 `nil` 이다. 빈 줄로 두면
    /// 무엇을 누르는지 알 수 없어 자리표시자를 넣는다.
    private var displayName: String {
        let name = peer.displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? Constants.unknownName : name
    }

    /// 파트·기수 둘 다 선택값이라 있는 것만 잇는다.
    private var subtitle: String {
        let part = peer.part.flatMap(UMCPartType.init(apiValue:))?.name ?? peer.part
        let generation = peer.generation.map { "\($0)기" }
        return [part, generation].compactMap { $0 }.joined(separator: Constants.separator)
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: .zero) {
            HStack(spacing: Metrics.contentSpacing) {
                RemoteImage(
                    urlString: peer.avatarURL ?? "",
                    size: CGSize(width: Metrics.avatarSize, height: Metrics.avatarSize)
                )

                VStack(alignment: .leading, spacing: Metrics.textSpacing) {
                    Text(displayName)
                        .appFont(.callout, weight: .semibold, color: .grey900)
                        .lineLimit(1)

                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .appFont(.footnote, color: .grey500)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: Metrics.contentSpacing)

            if hasSent {
                sentBadge
            } else {
                signal
            }
        }
        .padding(Metrics.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Metrics.height)
        .background(Color.grey000, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        .shadow(
            color: .black.opacity(Metrics.shadowOpacity),
            radius: Metrics.shadowRadius,
            y: Metrics.shadowY
        )
    }

    // MARK: - View Component

    /// 전송이 끝난 행은 신호 세기 대신 결과를 보여 준다 — 막대만 계속 그리면
    /// 눌렀다는 사실이 화면 어디에도 남지 않는다.
    private var sentBadge: some View {
        HStack(spacing: Metrics.textSpacing) {
            Image(systemName: Constants.sentImage)
                .font(.system(size: Metrics.signalSize))

            Text(Constants.sentTitle)
                .appFont(.footnote)
        }
        .foregroundStyle(BusinessCardPalette.indigo)
    }

    /// 거리는 UWB(NearbyInteraction)가 잰다. 미탑재 기기이거나 아직 못 쟀으면 `nil` 이라
    /// 막대만 두고 숫자를 비운다 — 「0.0m」로 채우면 옆에 있다는 거짓말이 된다.
    private var signal: some View {
        VStack(alignment: .trailing, spacing: Metrics.textSpacing) {
            Image(systemName: Constants.signalImage)
                .font(.system(size: Metrics.signalSize))
                .foregroundStyle(BusinessCardPalette.indigo)

            if let meters = peer.distanceMeters {
                Text(String(format: "%.1fm", meters))
                    .appFont(.footnote, color: BusinessCardPalette.indigo)
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("피어 행") {
    VStack(spacing: 8) {
        DiscoveredPeerRow(peer: DiscoveredPeer(
            id: "a",
            displayName: "이름/닉네임", part: "IOS", generation: "10",
            avatarURL: nil, distanceMeters: 2.1
        ))

        DiscoveredPeerRow(peer: DiscoveredPeer(
            id: "b"
        ))

        DiscoveredPeerRow(
            peer: DiscoveredPeer(
                id: "c", cardUUIDPrefix: Data(), version: 1, flags: 0,
                displayName: "보낸 상대", part: "IOS", generation: "10"
            ),
            hasSent: true
        )
    }
    .padding(16)
}
#endif
