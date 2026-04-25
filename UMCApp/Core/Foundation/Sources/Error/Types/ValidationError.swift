//
//  ValidationError.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 1/7/25.
//

import Foundation

/// 입력 유효성 검증 에러
public enum ValidationError: Error, LocalizedError, Equatable {
    /// 필수 입력값 누락
    case empty(field: String)

    /// 형식 오류 (이메일, 전화번호 등)
    case invalidFormat(field: String, expected: String)

    /// 최소 길이 미달
    case tooShort(field: String, minLength: Int)

    /// 최대 길이 초과
    case tooLong(field: String, maxLength: Int)

    /// 유효하지 않은 값
    case invalidValue(field: String, reason: String)

    /// 두 필드 값 불일치 (비밀번호 확인 등)
    case mismatch(field1: String, field2: String)

    /// 이미 사용 중인 값 (이메일 등)
    case alreadyInUse(field: String)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .empty(let field):
            return "\(field)을(를) 입력해주세요."
        case .invalidFormat(let field, let expected):
            return "\(field)의 형식이 올바르지 않습니다. (\(expected))"
        case .tooShort(let field, let minLength):
            return "\(field)은(는) 최소 \(minLength)자 이상이어야 합니다."
        case .tooLong(let field, let maxLength):
            return "\(field)은(는) \(maxLength)자를 초과할 수 없습니다."
        case .invalidValue(let field, let reason):
            return "\(field): \(reason)"
        case .mismatch(let field1, let field2):
            return "\(field1)와(과) \(field2)이(가) 일치하지 않습니다."
        case .alreadyInUse(let field):
            return "이미 사용 중인 \(field)입니다."
        }
    }

    /// 사용자에게 표시할 메시지 (errorDescription과 동일)
    public var userMessage: String {
        errorDescription ?? ""
    }
}
