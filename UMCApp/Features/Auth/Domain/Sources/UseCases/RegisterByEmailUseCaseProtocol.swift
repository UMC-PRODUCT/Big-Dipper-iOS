//
//  RegisterByEmailUseCaseProtocol.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 이메일(ID/PW) 회원가입 UseCase 인터페이스
public protocol RegisterByEmailUseCaseProtocol {
    /// 이메일(ID/PW) 회원가입을 완료한다.
    /// - Parameters:
    ///   - rawPassword: 원문 비밀번호
    ///   - name: 이름
    ///   - nickname: 닉네임
    ///   - emailVerificationToken: 이메일 인증 완료 토큰
    ///   - schoolId: 선택한 학교 식별자
    ///   - termsAgreements: 약관 동의 목록
    /// - Returns: 가입 결과
    func execute(
        rawPassword: String,
        name: String,
        nickname: String,
        emailVerificationToken: String,
        schoolId: String,
        termsAgreements: [TermsAgreement]
    ) async throws -> RegisterByIdPwResult
}
