//
//  FetchTermsUseCaseProtocol.swift
//  MyPageDomain
//
//  Created by One on 5/6/26.
//

import Foundation

/// 마이페이지 이용약관 조회 UseCase Protocol
///
/// 마이페이지에서 노션에 있는 이용약관 페이지에 연결합니다.
public protocol FetchTermsUseCaseProtocol {
    /// 이용약관을 불러옵니다.
    ///
    /// - LawsType.apiType : 약관 조회 API에서 사용하는 termsType 값
    func execute(termsType: String) async throws -> MyPageTerms
}
