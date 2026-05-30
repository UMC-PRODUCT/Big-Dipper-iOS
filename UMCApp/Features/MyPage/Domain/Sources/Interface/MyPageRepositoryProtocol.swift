//
//  MyPageRepositoryProtocol.swift
//  MyPageDomain
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation
import CoreDomain

/// MyPage 데이터 접근 Repository Protocol
public protocol MyPageRepositoryProtocol: Sendable {

    /// 내 프로필 조회
    func fetchMyProfile() async throws -> ProfileData

    /// 특정 멤버 프로필 조회
    func fetchMemberProfile(memberId: String) async throws -> MemberProfileSummary

    /// 내가 쓴 글 목록을 조회합니다.
    func fetchMyPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage

    /// 댓글 단 글 목록을 조회합니다.
    func fetchCommentedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage

    /// 스크랩한 글 목록을 조회합니다.
    func fetchScrappedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage

    /// 약관 타입으로 약관 링크 정보를 조회합니다.
    func fetchTerms(termsType: String) async throws -> MyPageTerms

    // MARK: - 보류 (다음 이슈에서 복원)
    //
    // 아래 5개 메서드는 의존 인프라(ChallengerMemberDTO / Storage / 서버 에러 매핑)와 함께
    // 별도 이슈에서 복원합니다. 복원 시 이 주석을 해제하고 Repository 구현체를 추가하세요.
    //
    // /// 특정 챌린저 프로필 조회
    // func fetchChallengerProfile(challengerId: String) async throws -> MemberProfileSummary
    //
    // /// 운영진 발급 코드로 챌린저 기록을 추가합니다.
    // func addChallengerRecord(code: String) async throws
    //
    // /// 프로필 이미지를 업로드하고 회원 프로필에 반영합니다.
    // /// 내부 흐름: prepare-upload -> signed URL 업로드 -> confirm -> member patch
    // func updateProfileImage(
    //     imageData: Data,
    //     fileName: String,
    //     contentType: String
    // ) async throws -> ProfileData
    //
    // /// 외부 프로필 링크(GitHub, LinkedIn, Blog) 정보를 서버에 반영합니다.
    // func updateProfileLinks(
    //     _ links: [ProfileLink]
    // ) async throws -> ProfileData
    //
    // /// 회원 탈퇴를 수행합니다.
    // func deleteMember() async throws
}
