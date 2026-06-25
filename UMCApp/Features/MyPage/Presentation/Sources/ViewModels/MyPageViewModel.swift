//
//  MyPageViewModel.swift
//  MyPagePresentation
//
//  Created by One on 5/24/26.
//

import Foundation
import UMCFoundation
import CoreDI
import MyPageDomain

/// MyPage 화면의 상태 및 비즈니스 로직을 관리하는 ViewModel.
///
/// `@Observable`을 사용하여 SwiftUI View와 양방향 데이터 바인딩을 수행합니다.
/// 사용자 프로필 데이터와 Alert 상태를 관리합니다.
///
/// - Note: 본 PR은 `fetchProfile`만 이식한 최소 set입니다. `connectSocial` 및
///   `/member-oauth/me` 기반 소셜 연동 동기화는 후속 이슈(Auth UseCase /
///   KakaoLoginManager / AppleLoginManager 이식 후)에서 복원됩니다.
@Observable
public final class MyPageViewModel {

    // MARK: - Property

    /// 사용자 프로필 데이터를 담는 Loadable 상태.
    public private(set) var profileData: Loadable<ProfileData> = .idle

    /// Alert 표시를 위한 프롬프트 상태 (확인/취소 다이얼로그).
    public var alertPrompt: AlertPrompt?

    private let container: DIContainer
    private let myPageProvider: MyPageUseCaseProviding

    // MARK: - Init

    public init(container: DIContainer) {
        self.container = container
        self.myPageProvider = container.resolve(MyPageUseCaseProviding.self)
    }

    #if DEBUG
    /// 프리뷰 전용 — 미리 로드된 프로필 상태로 시작합니다.
    public init(container: DIContainer, previewProfileData: ProfileData) {
        self.container = container
        self.myPageProvider = container.resolve(MyPageUseCaseProviding.self)
        self.profileData = .loaded(previewProfileData)
    }
    #endif

    // MARK: - Function

    /// 내 프로필을 조회합니다.
    ///
    /// 이미 로딩 중이면 중복 호출을 무시합니다. 에러 분기:
    /// - `CancellationError` / `NSURLErrorCancelled` → 이전 상태 복원
    /// - `AppError` → `.failed(error)`
    /// - 그 외 → `.failed(.unknown(message:))`
    ///
    /// - Important: 본 PR은 `/member-oauth/me` 동기화를 호출하지 않으므로
    ///   `socialConnections`는 항상 빈 배열로 세팅됩니다. 소셜 연동 표시는
    ///   Auth UseCase 이식 후속 PR에서 복원합니다.
    @MainActor
    public func fetchProfile() async {
        if profileData.isLoading { return }

        let previousState = profileData
        profileData = .loading

        do {
            var profile = try await myPageProvider.fetchMyPageProfileUseCase.execute()
            // TODO: Auth UseCase 이식 후속 PR에서 syncConnectedSocials() 호출로 교체
            profile.socialConnections = []
            profileData = .loaded(profile)
        } catch is CancellationError {
            profileData = previousState
        } catch let error as AppError {
            profileData = .failed(error)
        } catch let error as NSError
            where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
            profileData = previousState
        } catch {
            profileData = .failed(.unknown(message: error.localizedDescription))
        }
    }
}
