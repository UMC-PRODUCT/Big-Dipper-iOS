//
//  NoticeAlarmType.swift
//  HomeDomain
//
//  Created by euijjang97 on 1/20/26.
//

import Foundation

/// 알림 상태 타입 (성공, 정보, 경고, 에러)
///
/// 알림 보관함에서 알림의 성격을 구분하는 데 사용합니다.
/// 시각 매핑(SF Symbol, Color)은 `HomePresentation`의 extension에서 제공합니다.
public enum NoticeAlarmType: String, Codable, Sendable {
    /// 성공 상태
    case success
    /// 정보 상태
    case info
    /// 경고 상태
    case warning
    /// 에러 상태
    case error
}
