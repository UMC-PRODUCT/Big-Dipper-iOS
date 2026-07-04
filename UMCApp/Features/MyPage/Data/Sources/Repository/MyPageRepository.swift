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
    private let storageRepository: StorageRepositoryProtocol
    private let decoder: JSONDecoder

    // MARK: - Init

    public init(
        adapter: MoyaNetworkAdapter,
        storageRepository: StorageRepositoryProtocol,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.adapter = adapter
        self.storageRepository = storageRepository
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
    public func fetchMemberProfile(memberId: Int) async throws -> MemberProfileSummary {
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
    
    /// 특정 챌린저 포르필 조회
    public func addChallnegerRecord(code: String) async throws {
        do {
            let response = try await adapter.request(
                MyPageRouter.addChallengerRecord(code: code)
            )
            let apiResponse = try decoder.decode(
                APIResponse<EmptyResult>.self,
                from: response.data
            )
            try apiResponse.validateSuccess()
        } catch let error as NetworkError {
            throw Self.parseServerError(form: error) ?? error
        }
    }
    
    /// 프로필 이미지 업로드 3단계 플로우: prepare → upload → confirm → patch
    ///
    /// - Parameters:
    ///   - imageData: 업로드할 이미지 바이너리 데이터
    ///   - fileName: 파일 이름 (예: "profile.jpg")
    ///   - contentType: MIME 타입 (예: "image/jpeg")
    /// - Returns: 갱신된 프로필 데이터
    public func updateProfileImage(
        imageData: Data,
        fileName: String,
        contentType: String
    ) async throws -> ProfileData {
        let prepared = try await storageRepository.prepareUpload(
            fileName: fileName,
            contentType: contentType,
            fileSize: imageData.count,
            category: .profileImage
        )
        
        try await storageRepository.uploadFile(
            to: prepared.uploadUrl,
            data: imageData,
            method: prepared.uploadMethod,
            headers: prepared.headers,
            contentType: contentType
        )
        
        try await storageRepository.confirmUpload(fileId: prepared.fileId)
        
        return try await patchMemberProfileImage(profileImageId: prepared.fileId)
    }
    
    /// 프로필 외부 링크를 정규화한 뒤 서버에 PATCH 요청으로 반영합니다.
    ///
    /// - Parameter links: 수정할 프로필 링크 배열
    /// - Returns: 갱신된 프로필 데이터
    public func updateProfileLinks(
        _ links: [ProfileLink]
    ) async throws -> ProfileData {
        let request = UpdateMemberProfileLinksRequestDTO(
            links: normalizedProfileLinks(links).map {
                UpdateMemberProfileLinkRequestDTO(
                    type: $0.type.apiType,
                    link: $0.url
                )
            }
        )
        
        let response = try await adapter.request(
            MyPageRouter.patchMemberProfileLinks(
                request: request
            )
        )
        
        let apiResponse = try decoder.decode(
            APIResponse<MyPageProfileResponseDTO>.self,
            from: response.data
        )
        
        return try apiResponse.unwrap().toProfileData()
    }
    
    /// 회원 탈퇴 처리
    public func deleteMember() async throws {
        let response = try await adapter.request(MyPageRouter.deleteMember)
        let apiResponse = try decoder.decode(
            APIResponse<MyPageProfileResponseDTO>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
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
    private static func parseServerError(form error: NetworkError) -> Error? {
        guard case .requestFailed(_, let data) = error,
              let data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any]
        else {
            return nil
        }
        
        let code = json["code"] as? String
        let message = (json["message"] as? String) ?? (json["result"] as? String)
        
        guard code != nil || message != nil else {
            return nil
        }

        return RepositoryError.serverError(code: code, message: message)
    }
}

// MARK: - Private Function

private extension MyPageRepository {
    /// 게시글 페이지 API 응답을 `MyActivePostPage` 도메인으로 변환하는 공통 메서드.
    private func fetchPostPage(target: MyPageRouter) async throws -> MyActivePostPage {
        let response = try await adapter.request(target)
        let apiResponse = try decoder.decode(
            APIResponse<MyPagePostPageDTO<MyPagePostResponseDTO>>.self,
            from: response.data
        )
        let result = try apiResponse.unwrap()
        
        return MyActivePostPage(
            items: result.content.map { $0.toCommunityItemModel() },
            page: Int(result.page) ?? 0,
            hasNext: result.hasNext
        )
    }
    
    /// 업로드된 이미지 ID로 회원 프로필 이미지를 갱신합니다.
    private func patchMemberProfileImage(profileImageId: String) async throws -> ProfileData {
        let response = try await adapter.request(
            MyPageRouter.patchMember(
                request: UpdateMemberProfileImageRequestDTO(
                    profileImageId: profileImageId
                )
            )
        )
        
        let apiResponse = try decoder.decode(
            APIResponse<MyPageProfileResponseDTO>.self,
            from: response.data
        )
        
        return try apiResponse.unwrap().toProfileData()
    }
    
    /// 프로필 이미지 업로드 3단계 플로우: prepare → upload → confirm → patch
    ///
    /// - Parameters:
    ///   - imageData: 업로드할 이미지 바이너리 데이터
    ///   - fileName: 파일 이름 (예: "profile.jpg")
    ///   - contentType: MIME 타입 (예: "image/jpeg")
    /// - Returns: 갱신된 프로필 데이터
    private func normalizedProfileLinks(_ links: [ProfileLink]) -> [ProfileLink] {
        var mapped: [SocialLinkType: String] = [:]
        links.forEach { link in
            mapped[link.type] = link.url.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return SocialLinkType.allCases.map {
            ProfileLink(type: $0, url: mapped[$0] ?? "")
        }
    }
}
