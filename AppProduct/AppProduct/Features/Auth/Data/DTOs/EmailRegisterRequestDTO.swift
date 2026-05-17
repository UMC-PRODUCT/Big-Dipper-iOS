//
//  EmailRegisterRequestDTO.swift
//  AppProduct
//
//  Created by euijjang97 on 5/17/26.
//

import Foundation

/// 이메일 회원가입 API 요청 DTO
///
/// `POST /api/v1/member/register/email`
struct EmailRegisterRequestDTO: Encodable {

    // MARK: - Property

    /// 평문 비밀번호 (8자 이상)
    let rawPassword: String
    /// 사용자 실명 (1~10자)
    let name: String
    /// 닉네임 (`^[가-힣]+$`, 1~5자)
    let nickname: String
    /// 이메일 인증 토큰 (이메일 인증 완료 시 발급, 이메일 식별자 내장)
    let emailVerificationToken: String
    /// 학교 ID (서버 응답 String 기준)
    let schoolId: String
    /// 약관 동의 목록 (최소 1개 필수)
    let termsAgreements: [EmailRegisterTermsAgreementDTO]
}

/// 이메일 회원가입 약관 동의 항목 DTO
struct EmailRegisterTermsAgreementDTO: Encodable {

    // MARK: - Property

    /// 약관 ID (서버 응답 String 기준)
    let termsId: String
    /// 동의 여부
    let agreed: Bool
}
