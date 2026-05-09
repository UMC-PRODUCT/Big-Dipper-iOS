//
//  MyPageRepository.swift
//  MyPageData
//
//  Created by One on 5/6/26.
//

import Foundation
import Moya
import CoreNetwork
import UMCFoundation
import MyPageDomain

/// MyPage Repository 구현체
///
/// 프로필 조회/수정, 프로필 이미지 업로드, 회원 탈퇴, 활동 게시글 조회를 처리합니다.
public final class MyPageRepository: MyPageRepositoryProtocol, @unchecked Sendable {
    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let decoder: JSONDecoder

    // MARK: - Init

    public init(
        adapter: MoyaNetworkAdapter,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.adapter = adapter
        self.decoder = decoder
    }

    /// 약관 타입으로 약관 정보를 조회합니다.
    ///
    /// - Note: 인증 없이 호출 가능한 공개 API (`requestWithoutAuth`)를 사용합니다.
    public func fetchTerms(termsType: String) async throws -> MyPageTerms {
        let response = try await adapter.requestWithoutAuth(
            MyPageRouter.getTerms(termsType: termsType)
        )
        let apiResponse = try decoder.decode(
            APIResponse<MyPageTermsResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }
}
