//
//  AttendancePolicyError.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation

/// 출석 정책 입력 폼의 인라인 검증 에러
///
/// 일정 생성/수정 화면의 출석 정책 섹션에서 사용자 입력을 검증할 때 사용합니다.
/// 단조 증가(checkInStartAt < onTimeEndAt < lateEndAt) 와
/// 일정 종료 범위(lateEndAt ≤ endsAt) 위반 케이스를 표현합니다.
enum AttendancePolicyError: Equatable, Sendable {

    /// 시각 순서가 단조 증가가 아님
    case invalidOrder(OrderField)

    /// 지각 종료 시각이 일정 종료 시각을 초과함
    case lateExceedsEnd

    /// 단조 증가 위반 위치
    enum OrderField: Equatable, Sendable {
        /// 출석 시작 ≥ 출석 인정 마감
        case checkInVsOnTime
        /// 출석 인정 마감 ≥ 지각 인정 마감
        case onTimeVsLate
    }

    /// 화면에 노출할 한국어 메시지
    var message: String {
        switch self {
        case .invalidOrder(.checkInVsOnTime):
            return "출석 시작은 출석 인정 마감보다 빨라야 합니다."
        case .invalidOrder(.onTimeVsLate):
            return "출석 인정 마감은 지각 인정 마감보다 빨라야 합니다."
        case .lateExceedsEnd:
            return "지각 인정 마감은 일정 종료 시각을 넘을 수 없습니다."
        }
    }
}
