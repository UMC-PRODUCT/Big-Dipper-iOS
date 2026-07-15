//
//  AttendancePolicyError.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/27/26.
//

import Foundation

/// 출석 정책 입력 폼의 인라인 검증 에러
///
/// 스터디 일정 등록 화면의 출석 정책 섹션에서 사용자 입력을 검증할 때 사용합니다.
/// 단조 증가(checkInStartAt < onTimeEndAt < lateEndAt)와 일정 시작 범위
/// (checkInStartAt < startsAt) 위반 케이스를 표현합니다.
public enum AttendancePolicyError: Equatable, Sendable {

    /// 시각 순서가 단조 증가가 아님
    case invalidOrder(OrderField)

    /// 출석 시작 시각이 일정 시작 시각보다 늦거나 같음
    ///
    /// 서버(`POST /api/v2/schedules`)가 거부하는 조건이지만 범용 메시지만 내려주므로
    /// 클라이언트에서 선검증합니다.
    case checkInAfterScheduleStart

    /// 단조 증가 위반 위치
    public enum OrderField: Equatable, Sendable {
        /// 출석 시작 ≥ 출석 인정 마감
        case checkInVsOnTime
        /// 출석 인정 마감 ≥ 지각 인정 마감
        case onTimeVsLate
    }

    /// 화면에 노출할 한국어 메시지
    public var message: String {
        switch self {
        case .invalidOrder(.checkInVsOnTime):
            return "출석 시작은 출석 인정 마감보다 빨라야 합니다."
        case .invalidOrder(.onTimeVsLate):
            return "출석 인정 마감은 지각 인정 마감보다 빨라야 합니다."
        case .checkInAfterScheduleStart:
            return "출석 시작은 일정 시작보다 빨라야 합니다."
        }
    }
}
