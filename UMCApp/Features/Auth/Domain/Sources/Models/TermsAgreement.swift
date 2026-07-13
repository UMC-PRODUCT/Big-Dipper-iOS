//
//  TermsAgreement.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 약관 동의 여부.
///
/// 회원가입 UseCase 파라미터로 전달되는 도메인 모델이며, Data 레이어의 DTO와는 별개다.
public struct TermsAgreement: Equatable, Sendable {

    // MARK: - Property

    public let termsId: String
    public let isAgreed: Bool

    // MARK: - Init

    public init(termsId: String, isAgreed: Bool) {
        self.termsId = termsId
        self.isAgreed = isAgreed
    }
}
