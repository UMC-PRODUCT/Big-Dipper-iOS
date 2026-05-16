//
//  MissionStatus.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation

/// 미션 상태
///
/// UI 색상 매핑(`backgroundColor`, `foregroundColor` 등)은 Presentation 레이어
/// extension으로 제공됩니다.
public enum MissionStatus: String, CaseIterable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case pendingApproval = "대기중"
    case pass = "Pass"
    case fail = "Fail"
    case completed = "Completed"
    case locked = "Locked"

    /// 사용자에게 노출되는 표시 문자열
    public var displayText: String {
        switch self {
        case .notStarted, .locked:
            return "아직 열리지 않음"
        case .inProgress:
            return "In Progress"
        case .pendingApproval:
            return "대기중"
        case .pass:
            return "Pass"
        case .fail:
            return "Fail"
        case .completed:
            return "완료"
        }
    }

    /// 카드에 테두리(border)를 그릴지 여부
    ///
    /// 진행 중(In Progress) 상태에서만 강조 테두리를 사용합니다.
    public var hasBorder: Bool {
        self == .inProgress
    }
}
