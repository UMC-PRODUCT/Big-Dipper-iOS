//
//  AttendanceType.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// 출석 방식
///
/// GPS 위치 인증 출석과 사유 기반 출석 두 가지를 구분합니다.
public enum AttendanceType: String, Sendable {
    /// GPS 위치 인증을 통한 출석
    case gps

    /// 사유 제출을 통한 출석 (지각/결석 사유)
    case reason
}
