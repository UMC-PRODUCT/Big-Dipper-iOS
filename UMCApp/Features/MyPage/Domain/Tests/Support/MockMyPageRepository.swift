//
//  MockMyPageRepository.swift
//  MyPageDomainTests
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import UMCFoundation
import CoreDomain
@testable import MyPageDomain

/// UseCase 위임 테스트에서 공용으로 던지는 센티넬 에러
///
/// repository가 던진 에러가 UseCase를 통해 그대로 전파되는지 확인할 때 사용합니다.
enum MyPageTestError: Error, Equatable {
    case boom
}

/// `MyPageRepositoryProtocol`의 테스트용 Mock 구현체
///
/// UseCase가 **어떤 메서드를 어떤 인자로 호출했는지**를 기록하고(`...CallCount`, `...Received...`),
/// 각 메서드가 반환/던질 값을 주입할 수 있습니다(`...Result` / `...Error`).
///
/// 반환값을 주입하지 않은 메서드는 `MockError.notStubbed`를 던집니다. 따라서 UseCase가
/// 엉뚱한 repository 메서드를 호출하면(복붙 배선 실수) 기대 메서드의 `CallCount`가 0으로 남아
/// 테스트가 실패합니다 — 이것이 순수 위임 UseCase 테스트의 핵심 가치입니다.
final class MockMyPageRepository: MyPageRepositoryProtocol, @unchecked Sendable {

    enum MockError: Error, Equatable {
        /// 테스트가 반환값을 주입하지 않은 메서드가 호출됨
        case notStubbed
    }

    // MARK: - fetchMyProfile

    var fetchMyProfileResult: Result<ProfileData, Error> = .failure(MockError.notStubbed)
    private(set) var fetchMyProfileCallCount = 0
    private(set) var fetchMyProfileReceivedForceRefresh: Bool?

    func fetchMyProfile(forceRefresh: Bool) async throws -> ProfileData {
        fetchMyProfileCallCount += 1
        fetchMyProfileReceivedForceRefresh = forceRefresh
        return try fetchMyProfileResult.get()
    }

    // MARK: - fetchMemberProfile

    var fetchMemberProfileResult: Result<MemberProfileSummary, Error> = .failure(MockError.notStubbed)
    private(set) var fetchMemberProfileCallCount = 0
    private(set) var fetchMemberProfileReceivedMemberId: Int?

    func fetchMemberProfile(memberId: Int) async throws -> MemberProfileSummary {
        fetchMemberProfileCallCount += 1
        fetchMemberProfileReceivedMemberId = memberId
        return try fetchMemberProfileResult.get()
    }

    // MARK: - addChallengerRecord

    var addChallengerRecordError: Error?
    private(set) var addChallengerRecordCallCount = 0
    private(set) var addChallengerRecordReceivedCode: String?

    func addChallengerRecord(code: String) async throws {
        addChallengerRecordCallCount += 1
        addChallengerRecordReceivedCode = code
        if let addChallengerRecordError {
            throw addChallengerRecordError
        }
    }

    // MARK: - updateProfileImage

    var updateProfileImageResult: Result<ProfileData, Error> = .failure(MockError.notStubbed)
    private(set) var updateProfileImageCallCount = 0
    private(set) var updateProfileImageReceivedImageData: Data?
    private(set) var updateProfileImageReceivedFileName: String?
    private(set) var updateProfileImageReceivedContentType: String?

    func updateProfileImage(
        imageData: Data,
        fileName: String,
        contentType: String
    ) async throws -> ProfileData {
        updateProfileImageCallCount += 1
        updateProfileImageReceivedImageData = imageData
        updateProfileImageReceivedFileName = fileName
        updateProfileImageReceivedContentType = contentType
        return try updateProfileImageResult.get()
    }

    // MARK: - updateProfileLinks

    var updateProfileLinksResult: Result<ProfileData, Error> = .failure(MockError.notStubbed)
    private(set) var updateProfileLinksCallCount = 0
    private(set) var updateProfileLinksReceivedLinks: [ProfileLink]?

    func updateProfileLinks(_ links: [ProfileLink]) async throws -> ProfileData {
        updateProfileLinksCallCount += 1
        updateProfileLinksReceivedLinks = links
        return try updateProfileLinksResult.get()
    }

    // MARK: - deleteMember

    var deleteMemberError: Error?
    private(set) var deleteMemberCallCount = 0

    func deleteMember() async throws {
        deleteMemberCallCount += 1
        if let deleteMemberError {
            throw deleteMemberError
        }
    }

    // MARK: - fetchMyPosts

    var fetchMyPostsResult: Result<MyActivePostPage, Error> = .failure(MockError.notStubbed)
    private(set) var fetchMyPostsCallCount = 0
    private(set) var fetchMyPostsReceivedQuery: MyPagePostListQuery?

    func fetchMyPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        fetchMyPostsCallCount += 1
        fetchMyPostsReceivedQuery = query
        return try fetchMyPostsResult.get()
    }

    // MARK: - fetchCommentedPosts

    var fetchCommentedPostsResult: Result<MyActivePostPage, Error> = .failure(MockError.notStubbed)
    private(set) var fetchCommentedPostsCallCount = 0
    private(set) var fetchCommentedPostsReceivedQuery: MyPagePostListQuery?

    func fetchCommentedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        fetchCommentedPostsCallCount += 1
        fetchCommentedPostsReceivedQuery = query
        return try fetchCommentedPostsResult.get()
    }

    // MARK: - fetchScrappedPosts

    var fetchScrappedPostsResult: Result<MyActivePostPage, Error> = .failure(MockError.notStubbed)
    private(set) var fetchScrappedPostsCallCount = 0
    private(set) var fetchScrappedPostsReceivedQuery: MyPagePostListQuery?

    func fetchScrappedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        fetchScrappedPostsCallCount += 1
        fetchScrappedPostsReceivedQuery = query
        return try fetchScrappedPostsResult.get()
    }

    // MARK: - fetchTerms

    var fetchTermsResult: Result<MyPageTerms, Error> = .failure(MockError.notStubbed)
    private(set) var fetchTermsCallCount = 0
    private(set) var fetchTermsReceivedTermsType: String?

    func fetchTerms(termsType: String) async throws -> MyPageTerms {
        fetchTermsCallCount += 1
        fetchTermsReceivedTermsType = termsType
        return try fetchTermsResult.get()
    }
}

// MARK: - Fixtures

/// 위임 테스트에서 반환값으로 재사용할 최소 ProfileData 픽스처
func makeStubProfileData(challengeId: Int = 1) -> ProfileData {
    ProfileData(
        challengeId: challengeId,
        challengerInfo: ChallengerInfo(
            memberId: "1",
            challengerId: "1",
            gen: "11",
            name: "테스트",
            nickname: "tester",
            schoolName: "UMC",
            profileImage: nil,
            part: .pm
        ),
        socialConnections: [],
        activityLogs: [],
        profileLink: []
    )
}
