import CoreWatchDesignSystem
import Foundation

// MARK: - WatchFallbackPresentation

/// 폴백 화면 1장의 표시 계약. 색 단독으로 상태를 말하지 않도록 심볼·문구를 함께 강제한다.
struct WatchFallbackPresentation: Equatable, Sendable {
    let symbolName: String
    let status: WatchStatus
    let title: String
    let message: String
    let hint: String?
    let primaryAction: Action?
    let secondaryAction: Action?
    let disabledAction: DisabledAction?

    struct Action: Equatable, Sendable {
        let title: String
        let systemImage: String?
    }

    /// `WatchActionButton(disabledReason:)` 규약과 같다 — 사유 없는 비활성은 만들 수 없다.
    struct DisabledAction: Equatable, Sendable {
        let title: String
        let reason: String
    }
}

// MARK: - WatchFallbackPresentation + Dynamic Detail

extension WatchFallbackPresentation {

    /// 화면을 그리는 시점에만 알 수 있는 문구를 꽂는다 — `reason.presentation` 은 순수 정적
    /// 값이라 출석 시각(P0-5) · 남은 유효 시간(P0-7) · 공지 제목(P0-8) 같은 값을 담을 수 없다.
    /// 넘기지 않은 항목은 원래 문구를 그대로 둔다.
    func replacing(
        title: String? = nil,
        message: String? = nil,
        hint: String? = nil
    ) -> WatchFallbackPresentation {
        WatchFallbackPresentation(
            symbolName: symbolName,
            status: status,
            title: title ?? self.title,
            message: message ?? self.message,
            hint: hint ?? self.hint,
            primaryAction: primaryAction,
            secondaryAction: secondaryAction,
            disabledAction: disabledAction
        )
    }
}

// MARK: - WatchFallbackReason + Presentation

extension WatchFallbackReason {

    private typealias Action = WatchFallbackPresentation.Action
    private typealias DisabledAction = WatchFallbackPresentation.DisabledAction

    /// 화면 1장의 표시 계약. `default:` 를 두지 않는다 — 케이스가 늘면 컴파일 에러로 드러나야
    /// 새 실패 원인이 문구 없이 조용히 다른 화면으로 새지 않는다. 문체는 스펙 §5 원문대로
    /// `-습니다` 체로 통일한다(이미 머지된 워치 문구도 이 체를 쓴다).
    var presentation: WatchFallbackPresentation {
        switch self {
        case .locationPermissionDenied:
            return WatchFallbackPresentation(
                symbolName: "exclamationmark.triangle.fill",
                status: .warning,
                title: "위치 권한이 필요합니다",
                message: "출석을 확인하려면 위치 접근을 허용해 주세요.",
                hint: "iPhone 의 UMC 앱에서 위치 권한을 켜 주세요.",
                primaryAction: nil,
                secondaryAction: nil,
                disabledAction: nil
            )

        case .locationUnavailable:
            return WatchFallbackPresentation(
                symbolName: "location.slash.fill",
                status: .warning,
                title: "위치를 확인할 수 없습니다",
                message: "15초 안에 위치를 찾지 못했습니다.",
                hint: "실내나 지하에서는 위치 확인이 어렵습니다. 창가나 지상으로 이동해 주세요.",
                primaryAction: Action(title: "다시 시도", systemImage: nil),
                secondaryAction: nil,
                disabledAction: nil
            )

        case .phoneDisconnected:
            // 스펙의 "bt-slash" 에 대응하는 Bluetooth 글리프가 SF Symbols 에 없어
            // `iphone.slash` 로 대체한다 — 문구가 "iPhone 과 연결이 끊겼습니다"라 오히려
            // 더 정확하다.
            return WatchFallbackPresentation(
                symbolName: "iphone.slash",
                status: .warning,
                title: "iPhone 과 연결이 끊겼습니다",
                message: "마지막으로 받은 정보만 보여 주고 있습니다.",
                hint: "iPhone 을 가까이 두면 자동으로 다시 연결됩니다.",
                primaryAction: nil,
                secondaryAction: nil,
                disabledAction: nil
            )

        case .checkInRequestFailed:
            return WatchFallbackPresentation(
                symbolName: "xmark.octagon.fill",
                status: .error,
                title: "출석 요청에 실패했습니다",
                message: "요청이 서버에 닿지 않았습니다.",
                hint: "iPhone 의 UMC 앱에서 출석을 이어서 진행할 수 있습니다.",
                primaryAction: Action(title: "다시 시도", systemImage: nil),
                secondaryAction: Action(title: "iPhone 에서 시도", systemImage: nil),
                disabledAction: nil
            )

        case .alreadyCheckedIn:
            return WatchFallbackPresentation(
                symbolName: "checkmark.circle.fill",
                status: .success,
                title: "이미 출석 처리됨",
                message: "이 세션은 이미 출석으로 기록되었습니다.",
                hint: nil,
                primaryAction: nil,
                secondaryAction: nil,
                disabledAction: DisabledAction(
                    title: "출석 요청",
                    reason: "이미 출석이 처리된 세션입니다"
                )
            )

        case .checkInWindowClosed:
            return WatchFallbackPresentation(
                symbolName: "clock.fill",
                status: .error,
                title: "출석 인정 시간이 지났습니다",
                message: "이 세션은 결석으로 기록됩니다.",
                hint: "사유가 있다면 iPhone 에서 공결 사유를 제출해 주세요.",
                primaryAction: nil,
                secondaryAction: nil,
                disabledAction: DisabledAction(
                    title: "출석 요청",
                    reason: "출석 인정 시간이 지나 다시 제출할 수 없습니다"
                )
            )

        case .offlineQueued:
            // 남은 유효 시간은 화면을 그리는 시점의 현재 시각에 따라 계속 바뀌므로 정적
            // 문구로 고정할 수 없다 — `WatchOfflineQueueCard` 가 `replacing(hint:)` 로
            // 실제 값을 꽂는다.
            return WatchFallbackPresentation(
                symbolName: "arrow.up.circle.fill",
                status: .pending,
                title: "전송 대기 중",
                message: "네트워크가 연결되면 자동으로 보냅니다.",
                hint: nil,
                primaryAction: nil,
                secondaryAction: nil,
                disabledAction: nil
            )

        case .offlineQueueExpired:
            return WatchFallbackPresentation(
                symbolName: "clock.badge.exclamationmark.fill",
                status: .error,
                title: "전송 유효 시간이 지났습니다",
                message: "대기 중이던 출석 요청을 보내지 않고 버렸습니다.",
                hint: "iPhone 에서 공결 사유를 제출해 주세요.",
                primaryAction: nil,
                secondaryAction: nil,
                disabledAction: nil
            )

        case .mandatoryNoticeUnread:
            // 실제 공지 제목은 reason 밖(서버 데이터)에서 온다 — `WatchMandatoryNoticeBanner`
            // 가 `replacing(message:)` 로 실제 제목을 꽂는다.
            return WatchFallbackPresentation(
                symbolName: "exclamationmark.bubble.fill",
                status: .warning,
                title: "필수 확인 공지",
                message: "필수로 확인해야 하는 공지가 있습니다.",
                hint: nil,
                primaryAction: Action(title: "확인", systemImage: nil),
                secondaryAction: nil,
                disabledAction: nil
            )
        }
    }
}
