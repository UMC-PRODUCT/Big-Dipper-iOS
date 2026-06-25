//
//  MyPageUploadDTO.swift
//  MyPageData
//
//  마이페이지 프로필 이미지/링크 수정 요청 DTO 모음.
//

import Foundation

// MARK: - Profile Image

/// 회원 프로필 이미지 ID 수정 요청 DTO
///
/// `PATCH /api/v1/member` 요청 바디로 사용됩니다.
/// 업로드/confirm 단계에서 얻은 `profileImageId`를 회원 프로필에 반영합니다.
public struct UpdateMemberProfileImageRequestDTO: Encodable {
    public let profileImageId: String

    public init(profileImageId: String) {
        self.profileImageId = profileImageId
    }
}

// MARK: - Profile Links

/// 회원 정보 수정 요청 DTO (소셜/포트폴리오 링크)
///
/// `PATCH /api/v1/member/profile/links` 요청 바디로 사용됩니다.
public struct UpdateMemberProfileLinksRequestDTO: Encodable {
    /// 수정할 링크 항목 배열
    public let links: [UpdateMemberProfileLinkRequestDTO]

    public init(links: [UpdateMemberProfileLinkRequestDTO]) {
        self.links = links
    }
}

/// 링크 수정 요청 항목 DTO
public struct UpdateMemberProfileLinkRequestDTO: Encodable {
    /// 링크 타입 (예: "GITHUB", "LINKEDIN", "BLOG")
    public let type: String
    /// 링크 URL 문자열
    public let link: String

    public init(type: String, link: String) {
        self.type = type
        self.link = link
    }
}
