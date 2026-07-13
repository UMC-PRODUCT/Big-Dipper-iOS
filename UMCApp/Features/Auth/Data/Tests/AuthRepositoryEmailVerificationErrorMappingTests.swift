//
//  AuthRepositoryEmailVerificationErrorMappingTests.swift
//  AuthDataTests
//
//  Created by euijjang97 on 7/9/26.
//

import Testing
import UMCFoundation
import AuthDomain
@testable import AuthData

// MARK: - AuthRepository.mapEmailVerificationError(from: RepositoryError) 매핑 계약
//
// `AuthRepository`의 이메일 인증 에러 코드 매핑은 `private extension`에 있지만
// `internal static func`으로 개별 재정의해 `@testable import`로 직접 검증할 수 있다
// (레거시 `mapEmailVerificationError`와 코드↔의미 대응이 동일해야 한다).

@Suite("AuthRepository — mapEmailVerificationError 매핑")
struct AuthRepositoryEmailVerificationErrorMappingTests {

    @Test("AUTHENTICATION-0025 → invalidEmailFormat (이메일 형식 오류)")
    func mapsInvalidEmailFormat() {
        let result = AuthRepository.mapEmailVerificationError(
            from: .serverError(code: "AUTHENTICATION-0025", message: "형식 오류")
        )
        #expect(result == .invalidEmailFormat)
    }

    @Test("AUTHENTICATION-0026 → emailAlreadyExists (이미 가입된 이메일)")
    func mapsEmailAlreadyExists() {
        let result = AuthRepository.mapEmailVerificationError(
            from: .serverError(code: "AUTHENTICATION-0026", message: "이미 가입됨")
        )
        #expect(result == .emailAlreadyExists)
    }

    @Test("AUTHENTICATION-0027 → throttled (인증 요청 과다)")
    func mapsThrottled() {
        let result = AuthRepository.mapEmailVerificationError(
            from: .serverError(code: "AUTHENTICATION-0027", message: "요청 과다")
        )
        #expect(result == .throttled)
    }

    @Test("매핑되지 않는 코드는 nil을 반환한다 (default 경로)")
    func unmappedCodeReturnsNil() {
        let result = AuthRepository.mapEmailVerificationError(
            from: .serverError(code: "AUTHENTICATION-9999", message: "알 수 없는 오류")
        )
        #expect(result == nil)
    }

    @Test("code가 nil이면 nil을 반환한다 (default 경로)")
    func nilCodeReturnsNil() {
        let result = AuthRepository.mapEmailVerificationError(
            from: .serverError(code: nil, message: "메시지만 있음")
        )
        #expect(result == nil)
    }

    @Test("serverError가 아닌 RepositoryError는 nil을 반환한다")
    func nonServerErrorReturnsNil() {
        let result = AuthRepository.mapEmailVerificationError(
            from: .decodingError(detail: "디코딩 실패")
        )
        #expect(result == nil)
    }
}
