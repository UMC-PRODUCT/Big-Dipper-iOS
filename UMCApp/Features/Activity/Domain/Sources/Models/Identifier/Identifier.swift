//
//  Identifier.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

// MARK: - Identifier
// 서버 API 통신용 식별자 타입들
// - 타입 안전성: String 간 혼동 방지 (SessionID vs UserID)
// - SwiftUI Identifiable용 UUID와는 별개 (UUID는 ForEach/List diffing 전용)

/// 세션(스터디/세미나) 식별자
/// - 출석 요청, 세션 조회 등 서버 API 호출 시 사용
public struct SessionID: Hashable, Codable {
    public let value: String

    public init(value: String) {
        self.value = value
    }
}

/// 사용자 식별자
/// - 출석 요청, 사용자 정보 조회 등 서버 API 호출 시 사용
public struct UserID: Hashable, Codable {
    public let value: String

    public init(value: String) {
        self.value = value
    }
}

/// 출석 기록 식별자
/// - 출석 상태 변경, 출석 기록 조회 등 서버 API 호출 시 사용
public struct AttendanceID: Hashable, Codable {
    public let value: String

    public init(value: String) {
        self.value = value
    }
}
