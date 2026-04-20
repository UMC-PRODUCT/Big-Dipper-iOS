//
//  MockMyPageRepository.swift
//  AppProduct
//
//  Created by euijjang97 on 2/15/26.
//

import Foundation

final class MockMyPageRepository: MyPageRepositoryProtocol {
    func fetchMyProfile() async throws -> ProfileData {
        MyPageMockData.profile
    }

    func fetchMemberProfile(memberId: Int) async throws -> MemberProfileSummary {
        let profile = MyPageMockData.profile
        let latestRole = profile.activityLogs
            .sorted { $0.role > $1.role }
            .first
        return MemberProfileSummary(
            memberId: "\(memberId)",
            name: profile.challangerInfo.name,
            nickname: profile.challangerInfo.nickname,
            generation: profile.challangerInfo.gen,
            organizationName: nil,
            roleName: latestRole?.role.korean ?? "챌린저",
            profileImageURL: profile.challangerInfo.profileImage
        )
    }

    func fetchChallengerProfile(challengerId: Int) async throws -> MemberProfileSummary {
        let profile = MyPageMockData.profile
        let latestRole = profile.activityLogs
            .sorted { $0.role > $1.role }
            .first
        return MemberProfileSummary(
            memberId: "\(challengerId)",
            name: profile.challangerInfo.name,
            nickname: profile.challangerInfo.nickname,
            generation: profile.challangerInfo.gen,
            organizationName: nil,
            roleName: latestRole?.role.korean ?? "챌린저",
            profileImageURL: profile.challangerInfo.profileImage
        )
    }

    func addChallengerRecord(code: String) async throws {
        _ = code
    }

    func updateProfileImage(
        imageData: Data,
        fileName: String,
        contentType: String
    ) async throws -> ProfileData {
        MyPageMockData.profile
    }

    func updateProfileLinks(
        _ links: [ProfileLink]
    ) async throws -> ProfileData {
        let target = MyPageMockData.profile
        var profile = target
        profile.profileLink = links
        return profile
    }

    func deleteMember() async throws {}

    func fetchMyPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        MyPageMockData.page(query: query)
    }

    func fetchCommentedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        MyPageMockData.page(query: query)
    }

    func fetchScrappedPosts(query: MyPagePostListQuery) async throws -> MyActivePostPage {
        MyPageMockData.page(query: query)
    }

    func fetchTerms(termsType: String) async throws -> MyPageTerms {
        MyPageMockData.terms(for: termsType)
    }
}
