//
//  RegisterByIdPwRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 4/29/26.
//

import Foundation

/// ID/PW 회원가입 API 요청 DTO
struct RegisterByIdPwRequestDTO: Encodable {

    // MARK: - Property

    /// 이메일 인증 토큰 (이메일 인증 완료 시 발급)
    let emailVerificationToken: String
    /// 로그인 ID (사용자 입력, 서버 형식 검증)
    let loginId: String
    /// 사용자 실명 (1~10자)
    let name: String
    /// 닉네임 (`^[가-힣]+$`, 1~5자)
    let nickname: String
    /// 평문 비밀번호 (8자 이상)
    let rawPassword: String
    /// 학교 ID (서버 응답 String 기준)
    let schoolId: String
    /// 약관 동의 목록
    let termsAgreements: [RegisterByIdPwTermsAgreementDTO]
}

/// ID/PW 회원가입 약관 동의 항목 DTO
struct RegisterByIdPwTermsAgreementDTO: Encodable {

    // MARK: - Property

    /// 약관 ID (서버 응답 String 기준)
    let termsId: String
    /// 동의 여부
    let agreed: Bool
}
