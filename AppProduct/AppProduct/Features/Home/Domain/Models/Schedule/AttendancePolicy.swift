//
//  AttendancePolicy.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 일정에 부착된 출석 정책 도메인 모델
///
/// 서버 V2 일정 응답에 임베드되어 내려오는 정책 값입니다.
/// 클라이언트 상수(지오펜스 반경, 정시/지각 임계 분 등)는 ``AttendanceGeofenceConstants`` 를 사용합니다.
///
/// - SeeAlso: ``AttendanceGeofenceConstants``
struct AttendancePolicy: Equatable, Sendable {

    /// 출석 체크인 시작 시각 (이전엔 출석 불가)
    let checkInStartAt: Date

    /// 정시 출석 종료 시각 (이후엔 지각)
    let onTimeEndAt: Date

    /// 지각 종료 시각 (이후엔 결석)
    let lateEndAt: Date
}
