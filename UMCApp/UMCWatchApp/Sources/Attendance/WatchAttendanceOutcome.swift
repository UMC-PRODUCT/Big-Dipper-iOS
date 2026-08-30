//
//  WatchAttendanceOutcome.swift
//  UMCWatchApp
//
//  Created by euijjang97 on 8/30/26.
//

import CoreWatchDesignSystem
import SwiftUI

// MARK: - WatchAttendanceOutcome

/// 출석 결과. `ATTENDANCE_STATUS_CHANGED` 푸시의 `data.status` 원본 문자열에서 만든다.
///
/// `HomeDomain.ScheduleAttendanceStatus` 를 재사용하지 않는 이유: 그 enum 은 서버의
/// `"EXCUSED"` 를 `.present` 로 접어버려서 "공결에 초록(출석 확정)을 주지 않는다"는 워치 표시
/// 규칙을 표현할 수 없다. 접는 것 자체는 iOS 쪽 도메인 의미론(출석률 집계에서 공결을 출석으로
/// 본다)이라 바꾸면 iOS 화면 전반에 파급되므로, 워치 **표시 전용** enum 을 따로 둔다.
public enum WatchAttendanceOutcome: String, Sendable, Equatable, CaseIterable {
    /// 요청은 보냈고 운영진 승인을 기다리는 중 (`*_PENDING`).
    case pending
    /// 출석 확정 (`PRESENT`).
    case present
    /// 지각 확정 (`LATE`).
    case late
    /// 공결 인정 (`EXCUSED`).
    case excused
    /// 결석 (`ABSENT`).
    case absent

    // MARK: - Init

    /// - Parameter serverStatus: 푸시 페이로드 `data.status` 원본.
    ///   서버에 새 `*_PENDING` 변형이 추가돼도, 알 수 없는 값이 와도 승인 대기로 흡수한다 —
    ///   결과를 못 읽었다고 결석/출석 중 한쪽으로 단정하면 사용자를 오도한다.
    public init(serverStatus: String) {
        switch serverStatus {
        case "PRESENT": self = .present
        case "LATE":    self = .late
        case "EXCUSED": self = .excused
        case "ABSENT":  self = .absent
        default:        self = .pending
        }
    }

    // MARK: - Property

    public var title: String {
        switch self {
        case .pending: "승인 대기"
        case .present: "출석 확정"
        case .late:    "지각 확정"
        case .excused: "공결 인정"
        case .absent:  "결석"
        }
    }

    /// 시맨틱 상태 축 매핑. 공결이 `.pending` 과 같은 중립인 것은 의도다 —
    /// 초록은 출석 확정 전용이라 공결에 쓰면 출석률 표기와 어긋난다.
    /// 대기와의 구분은 색이 아니라 심볼 실루엣과 링 유무가 진다(`symbolName`·`ringTint`).
    public var status: WatchStatus {
        switch self {
        case .pending, .excused: .pending
        case .present:           .success
        case .late:              .warning
        case .absent:            .error
        }
    }

    /// 결과 화면의 대형 심볼. 공결만 `WatchStatus` 기본 심볼을 쓰지 않는다 —
    /// 대기와 같은 `.pending` 을 쓰면서도 실루엣(도장 체크 vs 점+링)으로 구분되어야 한다.
    public var symbolName: String {
        self == .excused ? "checkmark.seal" : status.symbolName
    }

    public var symbolTint: Color { status.tint }

    /// 팔레트 렌더링의 2차 색. 공결은 **링 없는 중립 솔리드**라 1차 색과 같은 값을 준다 —
    /// `status.ringTint` 를 그대로 쓰면 대기와 똑같은 인디고 링이 붙어 둘이 섞인다.
    public var ringTint: Color {
        self == .excused ? symbolTint : status.ringTint
    }

    /// 결과 카드 표면. 출석 확정만 Hero 로 띄우고, 결석은 위험 표면, 나머지는 일반 표면이다.
    /// 지각을 `.danger` 로 두지 않는 이유: 지각은 출석으로 인정된 결과라 실패가 아니다.
    public var cardStyle: WatchCardStyle {
        switch self {
        case .present:                  .hero
        case .absent:                   .danger
        case .pending, .late, .excused: .standard
        }
    }
}
