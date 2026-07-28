//
//  MyPageProfileViewModelTests.swift
//  MyPagePresentationTests
//
//  Created by 김동민 on 7/13/26.
//

import Testing
import Foundation
import UMCFoundation
import CoreDomain
import MyPageDomain
@testable import MyPagePresentation

@MainActor
@Suite("MyPageProfileViewModel — 제출 가능 여부 / 이미지·링크 수정 / 활동 이력 추가")
struct MyPageProfileViewModelTests {

    // MARK: - canSubmit

    @Test("변경이 없으면 canSubmit은 false")
    func canSubmitFalseWithoutChanges() {
        let viewModel = makeViewModel(profile: makeStubProfileData())
        #expect(viewModel.canSubmit == false)
    }

    @Test("이미지를 선택하면 canSubmit은 true")
    func canSubmitTrueAfterImageSelection() async {
        let viewModel = makeViewModel(profile: makeStubProfileData())

        await viewModel.didLoadImage(image: makeStubImage())

        #expect(viewModel.canSubmit == true)
    }

    @Test("링크가 최초 스냅샷과 달라지면 canSubmit은 true")
    func canSubmitTrueAfterLinkChange() {
        let viewModel = makeViewModel(profile: makeStubProfileData(profileLink: []))

        viewModel.profileData.profileLink = [
            ProfileLink(type: .github, url: "https://github.com/tester")
        ]

        #expect(viewModel.canSubmit == true)
    }

    // MARK: - submitProfileUpdate

    @Test("변경 없이 submit하면 어떤 UseCase도 호출하지 않음 (no-op)")
    func submitWithoutChangesIsNoOp() async throws {
        let mock = MockMyPageRepository()
        let viewModel = makeViewModel(profile: makeStubProfileData(), repository: mock)

        try await viewModel.submitProfileUpdate()

        #expect(mock.updateProfileImageCallCount == 0)
        #expect(mock.updateProfileLinksCallCount == 0)
    }

    @Test("이미지 변경 submit — updateProfileImage 호출 + jpeg 메타데이터 + socialConnections 보존")
    func submitImageUpdateCallsImageUseCase() async throws {
        let original = makeStubProfileData(
            challengeId: 1,
            socialConnections: [SocialConnection(memberOAuthId: 10, socialType: .kakao)]
        )
        // 서버 응답의 socialConnections가 비어 있어도 VM이 로컬 값을 복원해야 함
        let serverProfile = makeStubProfileData(challengeId: 42, socialConnections: [])
        let mock = MockMyPageRepository()
        mock.updateProfileImageResult = .success(serverProfile)
        let viewModel = makeViewModel(profile: original, repository: mock)

        await viewModel.didLoadImage(image: makeStubImage())
        try await viewModel.submitProfileUpdate()

        #expect(mock.updateProfileImageCallCount == 1)
        #expect(mock.updateProfileImageReceivedContentType == "image/jpeg")
        #expect(mock.updateProfileImageReceivedFileName?.hasPrefix("profile_") == true)
        #expect(mock.updateProfileImageReceivedFileName?.hasSuffix(".jpg") == true)
        #expect(viewModel.profileData.challengeId == 42)
        #expect(viewModel.profileData.socialConnections == original.socialConnections)
        // 제출 후 선택 상태 초기화
        #expect(viewModel.selectedPhotoItem == nil)
        #expect(viewModel.isUpdatingProfileImage == false)
        #expect(viewModel.canSubmit == false)
    }

    @Test("링크 변경 submit — updateProfileLinks 호출 + 전체 SocialLinkType 정규화 전달")
    func submitLinkUpdateCallsLinksUseCase() async throws {
        let serverProfile = makeStubProfileData(challengeId: 7)
        let mock = MockMyPageRepository()
        mock.updateProfileLinksResult = .success(serverProfile)
        let viewModel = makeViewModel(profile: makeStubProfileData(profileLink: []), repository: mock)

        viewModel.profileData.profileLink = [
            ProfileLink(type: .github, url: "https://github.com/tester")
        ]
        try await viewModel.submitProfileUpdate()

        #expect(mock.updateProfileImageCallCount == 0)
        #expect(mock.updateProfileLinksCallCount == 1)
        // 모든 SocialLinkType 케이스가 정규화되어 전달됨
        #expect(mock.updateProfileLinksReceivedLinks?.count == SocialLinkType.allCases.count)
        let github = mock.updateProfileLinksReceivedLinks?.first { $0.type == .github }
        #expect(github?.url == "https://github.com/tester")
        #expect(viewModel.profileData.challengeId == 7)
        #expect(viewModel.canSubmit == false)
    }

    @Test("이미지+링크 동시 변경 시 두 UseCase 모두 호출")
    func submitImageAndLinkCallsBothUseCases() async throws {
        let mock = MockMyPageRepository()
        mock.updateProfileImageResult = .success(makeStubProfileData(challengeId: 100))
        mock.updateProfileLinksResult = .success(makeStubProfileData(challengeId: 200))
        let viewModel = makeViewModel(profile: makeStubProfileData(profileLink: []), repository: mock)

        await viewModel.didLoadImage(image: makeStubImage())
        viewModel.profileData.profileLink = [
            ProfileLink(type: .blog, url: "https://blog.example.com")
        ]
        try await viewModel.submitProfileUpdate()

        #expect(mock.updateProfileImageCallCount == 1)
        #expect(mock.updateProfileLinksCallCount == 1)
    }

    @Test("이미지 업로드 실패 — 에러 전파 + 링크 UseCase 미호출 + 진행 플래그 복구 + 재시도용 pending 유지")
    func submitImageFailurePropagatesAndKeepsPendingState() async {
        let mock = MockMyPageRepository()
        mock.updateProfileImageResult = .failure(MyPageTestError.boom)
        let viewModel = makeViewModel(profile: makeStubProfileData(challengeId: 1), repository: mock)

        await viewModel.didLoadImage(image: makeStubImage())
        await #expect(throws: MyPageTestError.boom) {
            try await viewModel.submitProfileUpdate()
        }

        #expect(mock.updateProfileImageCallCount == 1)
        // 이미지 단계에서 throw되므로 링크 단계는 실행되지 않음
        #expect(mock.updateProfileLinksCallCount == 0)
        #expect(viewModel.profileData.challengeId == 1)
        // defer로 진행 플래그 복구 + 선택 이미지가 남아 있어 재시도 가능
        #expect(viewModel.isUpdatingProfileImage == false)
        #expect(viewModel.canSubmit == true)
    }

    @Test("링크 수정 실패 — 에러 전파 + 진행 플래그 복구 + 링크 diff 보존")
    func submitLinkFailurePropagatesAndKeepsLinkDiff() async {
        let mock = MockMyPageRepository()
        mock.updateProfileLinksResult = .failure(MyPageTestError.boom)
        let viewModel = makeViewModel(profile: makeStubProfileData(challengeId: 1, profileLink: []), repository: mock)

        viewModel.profileData.profileLink = [
            ProfileLink(type: .github, url: "https://github.com/tester")
        ]
        await #expect(throws: MyPageTestError.boom) {
            try await viewModel.submitProfileUpdate()
        }

        #expect(mock.updateProfileImageCallCount == 0)
        #expect(mock.updateProfileLinksCallCount == 1)
        #expect(viewModel.profileData.challengeId == 1)
        // 스냅샷이 갱신되지 않아 링크 diff가 남아 있어야 재시도 가능
        #expect(viewModel.isUpdatingProfileImage == false)
        #expect(viewModel.canSubmit == true)
    }

    @Test("이미지 성공 후 링크 실패 — 에러 전파 + 서버 응답 미반영 + 이미지/링크 pending 모두 보존")
    func submitLinkFailureAfterImageSuccessKeepsBothPendingStates() async {
        let mock = MockMyPageRepository()
        mock.updateProfileImageResult = .success(makeStubProfileData(challengeId: 100))
        mock.updateProfileLinksResult = .failure(MyPageTestError.boom)
        let viewModel = makeViewModel(profile: makeStubProfileData(challengeId: 1, profileLink: []), repository: mock)

        await viewModel.didLoadImage(image: makeStubImage())
        viewModel.profileData.profileLink = [
            ProfileLink(type: .blog, url: "https://blog.example.com")
        ]
        await #expect(throws: MyPageTestError.boom) {
            try await viewModel.submitProfileUpdate()
        }

        #expect(mock.updateProfileImageCallCount == 1)
        #expect(mock.updateProfileLinksCallCount == 1)
        // 링크 단계에서 throw되어 이미지 응답(challengeId 100)도 반영되지 않음
        #expect(viewModel.profileData.challengeId == 1)
        #expect(viewModel.isUpdatingProfileImage == false)
        #expect(viewModel.canSubmit == true)
    }

    // MARK: - addActivityLog

    @Test("addActivityLog 성공 — record 추가 후 프로필 재조회 + 성공 플래그 노출 + socialConnections 보존")
    func addActivityLogSuccess() async throws {
        let original = makeStubProfileData(
            challengeId: 1,
            socialConnections: [SocialConnection(memberOAuthId: 5, socialType: .apple)]
        )
        let refreshed = makeStubProfileData(challengeId: 55, socialConnections: [])
        let mock = MockMyPageRepository()
        mock.fetchMyProfileResult = .success(refreshed)
        let viewModel = makeViewModel(profile: original, repository: mock)

        try await viewModel.addActivityLog(code: "UMC-CODE")

        #expect(mock.addChallengerRecordCallCount == 1)
        #expect(mock.addChallengerRecordReceivedCode == "UMC-CODE")
        #expect(mock.fetchMyProfileCallCount == 1)
        #expect(viewModel.profileData.challengeId == 55)
        #expect(viewModel.profileData.socialConnections == original.socialConnections)
        #expect(viewModel.didRecentlyAddActivityLog == true)
        #expect(viewModel.isAddingActivityLog == false)
    }

    @Test("addActivityLog에서 record 추가 실패 시 에러 전파 + 프로필 미갱신 + 플래그 미노출")
    func addActivityLogFailurePropagates() async {
        let mock = MockMyPageRepository()
        mock.addChallengerRecordError = MyPageTestError.boom
        let viewModel = makeViewModel(profile: makeStubProfileData(challengeId: 1), repository: mock)

        await #expect(throws: MyPageTestError.boom) {
            try await viewModel.addActivityLog(code: "X")
        }

        #expect(mock.addChallengerRecordCallCount == 1)
        #expect(mock.fetchMyProfileCallCount == 0)
        #expect(viewModel.profileData.challengeId == 1)
        #expect(viewModel.didRecentlyAddActivityLog == false)
        #expect(viewModel.isAddingActivityLog == false)
    }
}

// MARK: - Helpers

@MainActor
private func makeViewModel(
    profile: ProfileData,
    repository: MockMyPageRepository = MockMyPageRepository()
) -> MyPageProfileViewModel {
    MyPageProfileViewModel(
        profileData: profile,
        useCaseProvider: makeUseCaseProvider(repository)
    )
}
