//
//  OperatorSessionStatus+UI.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/25/26.
//

import ActivityDomain
import CoreDesignSystem
import SwiftUI

/// `OperatorSessionStatus` 의 시각 표현 매핑.
///
/// 도메인 enum 이 SwiftUI 의존을 갖지 않도록 색상·라벨은 Presentation 레이어에 둡니다.
extension OperatorSessionStatus {

    /// 출석 현황 목록 카드 강조 색상 (좌측 액센트 바 + 상태 배지)
    ///
    /// 진행중=브랜드 강조, 예정=액센트, 마감=디엠퍼사이즈.
    var listAccentColor: Color {
        switch self {
        case .inProgress:  return .indigo500
        case .beforeStart: return .orange500
        case .ended:       return .grey400
        }
    }

    /// 목록 카드 상태 배지에 표시할 짧은 라벨
    ///
    /// 도메인 ``OperatorSessionStatus/displayText`` 는 "진행전/진행중/종료됨" 이며,
    /// 카드 배지는 폭 제약과 톤에 맞춰 "예정/진행중/마감" 을 사용합니다.
    var listBadgeText: String {
        switch self {
        case .inProgress:  return "진행중"
        case .beforeStart: return "예정"
        case .ended:       return "마감"
        }
    }
}
