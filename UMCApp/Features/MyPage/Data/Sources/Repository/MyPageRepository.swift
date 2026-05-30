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
import CoreDomain
import MyPageDomain

/// MyPage Repository 구현체
///
/// 프로필 조회/활동 게시글 조회/약관 조회를 처리합니다.
/// (수정·삭제 계열은 다음 이슈에서 추가됩니다 — `MyPageRepositoryProtocol`의 보류 메서드 참고)
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

    // MARK: - Profile

    /// 내 프로필 조회.
    public func fetchMyProfile() async throws -> ProfileData {
        let response = try await adapter.request(MyPageRouter.getMyProfile)
        let apiResponse = try decoder.decode(
            APIResponse<MyPageProfileResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toProfileData()
    }

    /// 특정 멤버 프로필 조회.
    ///
    /// 서버 응답이 `APIResponse` 래퍼 형식 또는 raw DTO 형식 어느 쪽이든 흡수합니다
    /// (구버전 endpoint 호환성 — AppProduct 구현 보존).
    public func fetchMemberProfile(memberId: String) async throws -> MemberProfileSummary {
        let response = try await adapter.request(
            MyPageRouter.getMemberProfile(memberId: memberId)
        )

        if let apiResponse = try? decoder.decode(
            APIResponse<MyPageProfileResponseDTO>.self,
            from: response.data
        ),
           let wrapped = try? apiResponse.unwrap() {
            return wrapped.toMemberProfileSummary()
        }

        let profile = try decoder.decode(
            MyPageProfileResponseDTO.self,
            from: response.data
        )
        return profile.toMemberProfileSummary()
    }

    // MARK: - Posts

    public func fetchMyPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        try await fetchPostPage(target: .getMyPosts(query: MyPagePostListQueryDTO(query: query)))
    }

    public func fetchCommentedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        try await fetchPostPage(target: .getCommentedPosts(query: MyPagePostListQueryDTO(query: query)))
    }

    public func fetchScrappedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        try await fetchPostPage(target: .getScrappedPosts(query: MyPagePostListQueryDTO(query: query)))
    }

    // MARK: - Terms

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

// MARK: - Private Helpers

private extension MyPageRepository {
    /// 게시글 페이지 API 응답을 `MyActivePostPage` 도메인으로 변환하는 공통 메서드.
    func fetchPostPage(target: MyPageRouter) async throws -> MyActivePostPage {
        let response = try await adapter.request(target)
        let apiResponse = try decoder.decode(
            APIResponse<MyPagePostPageDTO<MyPagePostResponseDTO>>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }
}
