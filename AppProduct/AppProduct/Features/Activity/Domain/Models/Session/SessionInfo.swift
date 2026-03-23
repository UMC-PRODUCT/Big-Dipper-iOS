//
//  SessionInfo.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/16/26.
//

import Foundation
import SwiftUI

/// 스터디/세미나 세션 정보
///
/// 출석 체크, 일정 표시 등에 사용되는 세션 데이터 모델입니다.
/// - Note: `id`는 SwiftUI List/ForEach용, `sessionId`는 서버 API용
struct SessionInfo: Identifiable, Equatable {
    let id: UUID = .init()
    let sessionId: SessionID
    let category: ScheduleIconCategory = .general
    let icon: ImageResource
    let title: String
    let week: Int
    let startTime: Date
    let endTime: Date
    let location: Coordinate
    var isAllDay: Bool = false
}

import CoreLocation

extension SessionInfo {
    /// 세션 위치를 MapKit 좌표로 변환
    func toCLLocationCoordinate2D() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
}
