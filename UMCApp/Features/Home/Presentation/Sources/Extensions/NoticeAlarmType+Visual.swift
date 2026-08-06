//
//  NoticeAlarmType+Visual.swift
//  HomePresentation
//
//  Created by euijjang97 on 1/20/26.
//

import CoreDesignSystem
import HomeDomain
import SwiftUI

/// `NoticeAlarmType` 에 대한 시각 표현(SF Symbol, 상태 색상) 매핑.
///
/// raw 값 정의는 `HomeDomain` 의 enum 에 위치하고,
/// SwiftUI 의존이 필요한 시각 토큰만 본 모듈에 분리합니다.
extension NoticeAlarmType {

    /// 상태별 시스템 심볼 이미지 이름
    var image: String {
        switch self {
        case .success: return "checkmark.circle"
        case .info:    return "info.circle"
        case .warning: return "exclamationmark.circle"
        case .error:   return "xmark.circle"
        }
    }

    /// 상태별 색상 토큰
    var color: Color {
        switch self {
        case .success: return .green500
        case .info:    return .indigo500
        case .warning: return .yellow500
        case .error:   return .red500
        }
    }
}
