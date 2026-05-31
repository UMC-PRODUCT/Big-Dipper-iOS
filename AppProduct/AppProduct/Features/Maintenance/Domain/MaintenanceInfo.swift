//
//  MaintenanceInfo.swift
//  AppProduct
//
//  원격 점검(킬스위치) 상태를 표현하는 도메인 모델.
//

import Foundation

/// 원격 점검 상태.
///
/// `RemoteConfig` 의 점검 플래그/문구를 앱 레이어에서 사용하기 위한 모델입니다.
/// `isActive` 가 `true` 일 때만 점검 화면으로 진입을 차단합니다.
struct MaintenanceInfo: Equatable {

    /// 점검 모드 활성화 여부.
    let isActive: Bool

    /// 점검 안내 제목.
    let title: String

    /// 점검 안내 본문.
    let message: String

    init(isActive: Bool, title: String, message: String) {
        self.isActive = isActive
        self.title = title
        self.message = message
    }
}
