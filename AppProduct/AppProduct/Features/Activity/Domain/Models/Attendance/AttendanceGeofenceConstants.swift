//
//  AttendanceGeofenceConstants.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/5/26.
//

import Foundation
import CoreLocation

/// GPS 기반 출석에 사용되는 클라이언트 상수 모음
///
/// 지오펜스 반경, 정시/지각 임계 시간 등 출석 판정에 사용되는 값들을 정의합니다.
/// 서버 정책 값(`AttendancePolicy` 도메인 모델, `checkInStartAt` 등)과 구분됩니다.
enum AttendanceGeofenceConstants {
    /// 지오펜스 반경 (미터)
    static let geofenceRadius: CLLocationDistance = 50.0
    /// 정시 출석 임계 시간 (분)
    static let onTimeThresholdMinutes: Int = 10
    /// 지각 임계 시간 (분)
    static let lateThresholdMinutes: Int = 30
}
