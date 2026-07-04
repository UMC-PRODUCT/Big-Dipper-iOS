//
//  File.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import SwiftUI

/// MyPage 설정 섹션의 항목 타입을 정의하는 열거형
///
/// 알림 설정, 위치 설정 등 사용자가 제어할 수 있는 앱 설정 항목들을 나타냅니다.
public enum SettingType: String, CaseIterable {
    /// 푸시 알림, 공지 알림 동의 설정
    case alarmSetting = "알림 설정"
    /// GPS 기반 출석 등에 필요한 위치 권한 설정
    case locationSetting = "위치 설정"
    
    /// 각 설정 항목에 맞는 SF Symbol 아이콘 이름
    public var icon: String {
        switch self {
        case .alarmSetting:
            return "bell"
        case .locationSetting:
            return "location"
        }
    }
    
    /// 각 설정 항목에 맞는 테마 색상
    public var color: Color {
        switch self {
        case .alarmSetting:
            return .pink
        case .locationSetting:
            return .mint
        }
    }
}
