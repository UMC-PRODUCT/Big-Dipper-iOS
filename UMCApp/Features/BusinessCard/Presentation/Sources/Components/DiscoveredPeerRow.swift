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

    /// 이 상대에게 명함을 보내는 중. 탭과 완료 화면 사이가 비면 사용자는 무반응으로
    /// 읽는다 — 신호 막대 자리를 진행 표시로 바꿔 그 구간을 메운다.
    var isSending: Bool = false

    // MARK: - Constants

    private enum Constants {
        static let unknownName = "이름 없는 멤버"
        static let signalImage = "cellularbars"
        static let sentTitle = "보냈어요"
        static let sentImage = "checkmark.circle.fill"
        /// 파트와 기수를 잇는 구분자. 시안 표기 `iOS ・10기`.
        static let separator = " ・"

        static let sendingLabel = "명함 보내는 중"
        static let unknownDistanceLabel = "거리 측정 중"
        static let actionHint = "이 멤버에게 내 명함을 보냅니다"

        static func distanceLabel(meters: Double) -> String {
            String(format: "약 %.1f미터", meters)
        }
    }

    private enum Metrics {
        /// 시안 실측 높이. **바닥값**이다 — 글자가 커지면 줄이 따라 늘어난다.
        static let minHeight: CGFloat = 80
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

    /// 거리를 막대 채움 비율(0…1)로 옮기는 구간. UWB(NearbyInteraction) 실효 사거리가
    /// 10m 안쪽이라 그 범위를 네 칸에 고르게 나눈다.
    private enum SignalRange {
        /// 이보다 가까우면 가득 찬다.
        static let near: Double = 1
        /// 이보다 멀면 한 칸만 남는다.
        static let far: Double = 9
        /// 사거리 밖에서도 막대가 통째로 비지 않게 남기는 하한.
        static let minimumFill: Double = 0.25
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

    /// 막대 채움 비율. 거리를 아직 못 쟀으면 `0` — 「가까움」을 뜻하는 가득 찬 막대가
    /// 기본값으로 뜨는 것을 막는다(`variableValue: nil` 은 전부 채워 그린다).
    private var signalFill: Double {
        guard let meters = peer.distanceMeters else { return .zero }

        let span = SignalRange.far - SignalRange.near
        let normalized = (SignalRange.far - meters) / span
        return min(1, max(SignalRange.minimumFill, normalized))
    }

    /// 줄 오른쪽이 지금 그리고 있는 것을 말로 옮긴 것. ``trailing`` 과 같은 순서라
    /// 보는 것과 듣는 것이 어긋나지 않는다.
    private var trailingLabel: String {
        guard !hasSent else { return Constants.sentTitle }
        return peer.distanceMeters
            .map(Constants.distanceLabel(meters:)) ?? Constants.unknownDistanceLabel
    }

    /// 「홍길동, iOS ・10기, 약 1.2미터」. 이름·파트·막대·거리가 따로 읽히면
    /// 목록을 훑는 동안 네 번씩 듣게 된다.
    ///
    /// 줄을 한 덩어리로 묶어 놓아서 「보냈어요」 뱃지가 따로 읽힐 길이 없다 —
    /// 그 사실도 여기서 같이 말한다.
    private var accessibilityLabel: String {
        [displayName, subtitle, trailingLabel]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
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

            trailing
        }
        .padding(Metrics.padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: Metrics.minHeight)
        .background(Color.grey000, in: RoundedRectangle(cornerRadius: Metrics.cornerRadius))
        .shadow(
            color: .black.opacity(Metrics.shadowOpacity),
            radius: Metrics.shadowRadius,
            y: Metrics.shadowY
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isSending ? Constants.sendingLabel : accessibilityLabel)
        .accessibilityHint(isSending ? "" : Constants.actionHint)
    }

    // MARK: - View Component

    /// 셋 다 줄 오른쪽 같은 자리를 쓴다 — 보내는 중 → 보냄 → 신호 세기 순으로
    /// 하나만 그린다. 전송 중에 「보냈어요」가 먼저 뜨면 아직 안 끝난 일이
    /// 끝난 것처럼 보인다.
    @ViewBuilder
    private var trailing: some View {
        if isSending {
            ProgressView().controlSize(.small)
        } else if hasSent {
            sentBadge
        } else {
            signal
        }
    }

    /// 전송이 끝난 행은 신호 세기 대신 결과를 보여 준다 — 막대만 계속 그리면
    /// 눌렀다는 사실이 화면 어디에도 남지 않는다.
    private var sentBadge: some View {
        HStack(spacing: Metrics.textSpacing) {
            Image(systemName: Constants.sentImage)
                .font(.system(size: Metrics.signalSize))

            Text(Constants.sentTitle)
                .appFont(.footnote)
        }
        // 아래 ``signal`` 막대와 같은 자리·같은 파랑이어야 한다. 시안 raw hex 대신
        // 코어 토큰을 쓴다 — 토큰은 다크 모드 값을 스스로 들고 있다 (#1237).
        .foregroundStyle(Color.indigo500)
    }

    /// 거리는 UWB(NearbyInteraction)가 잰다. 미탑재 기기이거나 아직 못 쟀으면 `nil` 이라
    /// 막대를 비우고 숫자를 감춘다 — 「0.0m」로 채우면 옆에 있다는 거짓말이 된다.
    ///
    /// 막대는 장식이 아니라 거리의 시각 표현이라 VoiceOver 에서는 숨기고, 같은 정보를
    /// 줄 전체 라벨이 말로 전달한다.
    private var signal: some View {
        VStack(alignment: .trailing, spacing: Metrics.textSpacing) {
            Image(systemName: Constants.signalImage, variableValue: signalFill)
                .font(.system(size: Metrics.signalSize))
                .foregroundStyle(Color.indigo500)

            if let meters = peer.distanceMeters {
                Text(String(format: "%.1fm", meters))
                    .appFont(.footnote, color: .indigo500)
                    .monospacedDigit()
            }
        }
        .accessibilityHidden(true)
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
            id: "b",
            displayName: "먼 멤버", part: "PM", generation: "12",
            avatarURL: nil, distanceMeters: 8.4
        ))

        // 거리 미측정 — 막대가 비어야 한다.
        DiscoveredPeerRow(peer: DiscoveredPeer(
            id: "c"
        ))

        DiscoveredPeerRow(
            peer: DiscoveredPeer(
                id: "d",
                displayName: "보낸 상대", part: "IOS", generation: "10"
            ),
            hasSent: true
        )

        DiscoveredPeerRow(
            peer: DiscoveredPeer(
                id: "e",
                displayName: "보내는 중", part: "IOS", generation: "10",
                avatarURL: nil, distanceMeters: 1.0
            ),
            isSending: true
        )
    }
    .padding(16)
}
#endif
