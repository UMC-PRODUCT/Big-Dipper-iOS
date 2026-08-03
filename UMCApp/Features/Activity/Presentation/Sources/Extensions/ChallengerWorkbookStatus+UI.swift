//
//  ChallengerWorkbookStatus+UI.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import CoreDesignSystem
import SwiftUI

/// ``ChallengerWorkbookStatus`` 의 시각 표현 매핑.
///
/// 도메인 enum 이 SwiftUI 의존을 갖지 않도록 색상·아이콘은 Presentation 레이어에 둡니다.
extension ChallengerWorkbookStatus {

    /// 상태 배지 강조 색상
    ///
    /// 통과=성공, 미통과=경고, 검토 중=브랜드 강조, 미배포/알 수 없음=디엠퍼사이즈.
    var badgeColor: Color {
        switch self {
        case .pass:          return .green700
        case .fail:          return .red700
        case .inProgress:    return .indigo500
        case .notSubmitted,
             .unknown:       return .grey500
        }
    }

    /// 상태 배지 아이콘 (SF Symbol)
    var badgeIcon: String {
        switch self {
        case .pass:          return "checkmark.seal.fill"
        case .fail:          return "exclamationmark.triangle.fill"
        case .inProgress:    return "clock.fill"
        case .notSubmitted:  return "tray"
        case .unknown:       return "questionmark.circle"
        }
    }
}
