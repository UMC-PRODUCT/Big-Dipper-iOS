//
//  MyPageRepositoryProtocol.swift
//  MyPageData
//
//  Created by One on 5/6/26.
//

import Foundation

/// MyPage 데이터 접근 Repository Protocol
public protocol MyPageRepositoryProtocol: Sendable {
    
    /// 약관 타입으로 약관 링크 정보를 조회합니다.
    func fetchTerms(termsType: String) async throws -> MyPageTerms
}
