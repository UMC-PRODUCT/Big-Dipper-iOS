//
//  AttendancePolicy.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation
import CoreLocation

/// 출석 정책 상수
///
/// GPS 출석의 지오펜스 반경과 시간 기준(정시/지각/결석)을 정의합니다.
public enum AttendancePolicy {
    /// GPS 출석 유효 반경 (미터)
    public static let geofenceRadius: CLLocationDistance = 50.0

    /// 정시 출석 허용 시간 (분) — 세션 시작 후 이 시간 내 출석 시 '출석'
    public static let onTimeThresholdMinutes: Int = 10

    /// 지각 허용 시간 (분) — 정시 이후 이 시간 내 출석 시 '지각'
    public static let lateThresholdMinutes: Int = 30
}
