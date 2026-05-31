//
//  ModifyViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 1/26/26.
//

import Foundation
import SwiftUI
import PhotosUI

/// 마이페이지 읽기 및 수정 화면의 비즈니스 로직을 담당하는 ViewModel입니다.
///
/// 프로필 데이터를 관리하고, 이미지 선택 및 업로드 동작을 처리합니다.
@Observable
class MyPageProfileViewModel: SinglePhotoPickerManageable {
    // MARK: - Property

    /// 프로파일 정보
    var profileData: ProfileData
    private let useCaseProvider: MyPageUseCaseProviding
    private let authUseCaseProvider: AuthUseCaseProviding
    private let kakaoLoginManager = KakaoLoginManager()
    private let googleLoginManager = GoogleLoginManager()

    // MARK: - 이미지 선택 관련

    /// PhotosPicker에서 선택된 아이템 (PHPickerResult)
    var selectedPhotoItem: PhotosPickerItem?
    
    /// 선택된 아이템에서 로드된 실제 이미지 객체
    var selectedImage: UIImage?

    /// 선택된 원본 이미지 바이너리 (업로드용)
    private var selectedImageData: Data?

    /// 프로필 이미지 수정 API 진행 상태
    var isUpdatingProfileImage: Bool = false

    /// 활동 이력 추가 API 진행 상태
    var isAddingActivityLog: Bool = false
    /// 활동 이력 추가 성공 후 버튼 성공 문구 노출 상태
    var didRecentlyAddActivityLog: Bool = false

    /// 소셜 연동 해제 API 진행 상태
    var disconnectingSocialType: SocialType?

    /// 최초 조회/수정 화면 진입 시 링크 스냅샷
    private var initialProfileLinkState: [SocialLinkType: String]
    /// 활동 이력 추가 성공 문구 자동 복귀 제어 태스크
    private var activityLogAddedResetTask: Task<Void, Never>?
    
    init(
        profileData: ProfileData,
        useCaseProvider: MyPageUseCaseProviding,
        authUseCaseProvider: AuthUseCaseProviding
    ) {
        self.profileData = profileData
        self.useCaseProvider = useCaseProvider
        self.authUseCaseProvider = authUseCaseProvider
        self.initialProfileLinkState = Self.makeProfileLinkState(from: profileData.profileLink)
    }
    
    // MARK: - Function

    /// 갤러리에서 이미지를 선택했을 때 호출되는 콜백입니다.
    /// - Parameter image: 로드된 UIImage 객체
    func didLoadImage(image: UIImage) async {
        selectedImageData = image.jpegData(compressionQuality: 0.9)
    }

    /// 저장 버튼 활성화 여부
    var canSubmit: Bool {
        !isUpdatingProfileImage && (hasPendingImageUpdate || hasPendingLinkUpdate)
    }

    /// 갤러리에서 새 이미지를 선택하여 업로드 대기 중인지 여부
    private var hasPendingImageUpdate: Bool {
        selectedImageData != nil
    }

    /// 현재 링크 상태가 최초 스냅샷과 달라져 서버 반영이 필요한지 여부
    private var hasPendingLinkUpdate: Bool {
        Self.makeProfileLinkState(from: normalizedProfileLinksForSubmit) != initialProfileLinkState
    }

    /// 프로필 이미지를 서버에 업로드 후 회원 정보에 반영합니다.
    ///
    /// JPEG 0.9 품질로 압축된 이미지를 서버에 업로드하고,
    /// 성공 시 로컬 프로필 데이터를 갱신한 뒤 선택 상태를 초기화합니다.
    ///
    /// - Throws: 네트워크 오류 또는 서버 에러
    /// - Important: 호출 전 `canSubmit`이 true인지 확인해야 합니다.
    @MainActor
    func submitProfileUpdate() async throws {
        guard !isUpdatingProfileImage else {
            return
        }

        let hasImageUpdate = selectedImageData != nil
        let hasLinkUpdate = hasPendingLinkUpdate
        guard hasImageUpdate || hasLinkUpdate else {
            return
        }

        isUpdatingProfileImage = true
        defer { isUpdatingProfileImage = false }

        var updatedProfile = profileData
        let currentSocialConnections = profileData.socialConnections

        if hasImageUpdate, let imageData = selectedImageData {
            let fileName = "profile_\(Int(Date().timeIntervalSince1970)).jpg"
            updatedProfile = try await useCaseProvider
                .updateMyPageProfileImageUseCase
                .execute(
                    imageData: imageData,
                    fileName: fileName,
                    contentType: "image/jpeg"
                )
        }

        if hasLinkUpdate {
            updatedProfile = try await useCaseProvider
                .updateMyPageProfileLinksUseCase
                .execute(profileLinks: normalizedProfileLinksForSubmit)
        }

        updatedProfile.socialConnections = currentSocialConnections
        profileData = updatedProfile
        initialProfileLinkState = Self.makeProfileLinkState(from: updatedProfile.profileLink)
        selectedImageData = nil
        selectedPhotoItem = nil
    }

    /// 운영진 발급 코드로 활동 이력을 추가하고 프로필 정보를 갱신합니다.
    @MainActor
    func addActivityLog(code: String) async throws {
        guard !isAddingActivityLog else {
            return
        }

        isAddingActivityLog = true
        defer { isAddingActivityLog = false }

        let currentSocialConnections = profileData.socialConnections
        try await useCaseProvider.addChallengerRecordUseCase.execute(code: code)
        profileData = try await useCaseProvider.fetchMyPageProfileUseCase.execute()
        profileData.socialConnections = currentSocialConnections
        initialProfileLinkState = Self.makeProfileLinkState(from: profileData.profileLink)
        showRecentActivityLogAddedState()
    }

    /// 특정 소셜 연동을 해제하고 최신 연동 목록으로 갱신합니다.
    @MainActor
    func disconnectSocial(_ connection: SocialConnection) async throws {
        guard disconnectingSocialType == nil else {
            return
        }

        disconnectingSocialType = connection.socialType
        defer { disconnectingSocialType = nil }

        let verification = try await makeDeleteVerification(for: connection.socialType)

        try await authUseCaseProvider.deleteMemberOAuthUseCase.execute(
            memberOAuthId: connection.memberOAuthId,
            googleAccessToken: verification.googleAccessToken,
            kakaoAccessToken: verification.kakaoAccessToken
        )

        let oauths = try await authUseCaseProvider.fetchMyOAuthUseCase.execute()
        let updatedConnections = oauths.compactMap(Self.makeSocialConnection(from:))
        profileData.socialConnections = updatedConnections
        SocialType.saveConnected(updatedConnections.map(\.socialType))
    }

    // MARK: - Private Method

    /// 현재 프로필 링크를 정규화하여 서버 제출용 배열로 반환합니다.
    private var normalizedProfileLinksForSubmit: [ProfileLink] {
        let currentLinks = Self.makeProfileLinkState(from: profileData.profileLink)

        return SocialLinkType.allCases.map {
            ProfileLink(
                type: $0,
                url: currentLinks[$0] ?? ""
            )
        }
    }

    /// 프로필 링크 배열을 `[SocialLinkType: String]` 스냅샷으로 변환합니다.
    ///
    /// 변경 감지(diff) 비교에 사용되며, URL 공백을 제거하고
    /// 모든 `SocialLinkType` 케이스에 대해 키를 보장합니다.
    private static func makeProfileLinkState(
        from profileLinks: [ProfileLink]
    ) -> [SocialLinkType: String] {
        var mapped: [SocialLinkType: String] = [:]
        profileLinks.forEach {
            mapped[$0.type] = $0.url.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return Dictionary(
            uniqueKeysWithValues: SocialLinkType.allCases.map { type in
                (type, mapped[type] ?? "")
            }
        )
    }

    private func makeDeleteVerification(
        for socialType: SocialType
    ) async throws -> (googleAccessToken: String?, kakaoAccessToken: String?) {
        switch socialType {
        case .kakao:
            let accessToken = try await kakaoLoginManager.fetchAccessToken()
            return (nil, accessToken)
        case .apple:
            return (nil, nil)
        case .google:
            let accessToken = try await googleLoginManager.fetchAccessToken()
            return (accessToken, nil)
        case .email:
            throw AuthError.socialLoginFailed(
                provider: socialType.rawValue,
                reason: "이메일 로그인은 OAuth 연동 해제 흐름의 대상이 아닙니다."
            )
        }
    }

    private static func makeSocialConnection(
        from memberOAuth: MemberOAuth
    ) -> SocialConnection? {
        guard let socialType = memberOAuth.provider.socialType else {
            return nil
        }

        return SocialConnection(
            memberOAuthId: memberOAuth.memberOAuthId,
            socialType: socialType
        )
    }

    /// 활동 이력 추가 성공 문구를 잠시 노출한 뒤 기본 상태로 복귀합니다.
    @MainActor
    private func showRecentActivityLogAddedState() {
        activityLogAddedResetTask?.cancel()
        didRecentlyAddActivityLog = true

        activityLogAddedResetTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.didRecentlyAddActivityLog = false
        }
    }
}
