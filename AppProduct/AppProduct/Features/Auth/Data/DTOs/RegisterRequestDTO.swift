//
//  RegisterRequestDTO.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/10/26.
//

import Foundation

/// 회원가입 API 요청 DTO
struct RegisterRequestDTO: Encodable {

    // MARK: - Property

    /// OAuth 인증 토큰 (소셜 로그인 시 발급)
    let oAuthVerificationToken: String
    /// 사용자 실명
    let name: String
    /// 닉네임
    let nickname: String
    /// 이메일 인증 토큰 (이메일 인증 완료 시 발급)
    let emailVerificationToken: String
    /// 학교 ID (서버가 String 반환)
    let schoolId: String
    /// 프로필 이미지 ID (선택)
    let profileImageId: String?
    /// 약관 동의 목록
    let termsAgreements: [TermsAgreementDTO]
}

/// 약관 동의 항목 DTO
struct TermsAgreementDTO: Encodable {

    // MARK: - Property

    /// 약관 ID (서버 응답 문자열 기준)
    let termsId: String
    /// 동의 여부
    let isAgreed: Bool
}
