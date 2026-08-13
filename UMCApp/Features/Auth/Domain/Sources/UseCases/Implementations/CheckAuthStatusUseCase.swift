//
//  CheckAuthStatusUseCase.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/8/26.
//

import CoreDomain
import Foundation
import UMCFoundation

/// 앱 부트스트랩 시점의 인증 상태 판정 UseCase 구현체
///
/// 토큰 존재 → 세션 강제 갱신 → 프로필 조회 → 승인 판정 순으로 진행한다.
/// 세션 강제 갱신이 실패해도 기존 액세스 토큰으로 프로필 조회를 한 번 더 시도한다
/// (레거시 `AuthBootstrapViewModel.resolveAuthStatus()`와 동일한 완화 정책).
public final class CheckAuthStatusUseCase: CheckAuthStatusUseCaseProtocol {

    // MARK: - Property

    private let repository: AuthRepositoryProtocol
    private let fetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol
    private let syncProfileStorageUseCase: SyncProfileStorageUseCaseProtocol
    private let userDefaults: UserDefaults

    // MARK: - Init

    public init(
        repository: AuthRepositoryProtocol,
        fetchMemberProfileUseCase: FetchMemberProfileUseCaseProtocol,
        syncProfileStorageUseCase: SyncProfileStorageUseCaseProtocol,
        userDefaults: UserDefaults = .standard
    ) {
        self.repository = repository
        self.fetchMemberProfileUseCase = fetchMemberProfileUseCase
        self.syncProfileStorageUseCase = syncProfileStorageUseCase
        self.userDefaults = userDefaults
    }

    // MARK: - Function

    public func execute() async -> AuthBootstrapStatus {
        guard await repository.hasSession() else {
            return .notLoggedIn
        }

        var refreshFailedOnTransport = false
        do {
            try await repository.refreshSession()
        } catch {
            // 갱신 실패 시에도 기존 액세스 토큰으로 프로필 조회를 시도한다.
            refreshFailedOnTransport = error.isTransportFailure
        }

        let canAutoLogin = userDefaults.bool(forKey: AppStorageKey.canAutoLogin)

        do {
            let profile = try await fetchMemberProfileUseCase.execute()
            guard profile.isApproved else {
                return canAutoLogin ? .pendingApproval : .notLoggedIn
            }
            syncProfileStorageUseCase.execute(profile: profile)
            return .approved
        } catch {
            let blockedByTransport = error.isTransportFailure || refreshFailedOnTransport
            // 자동 로그인이 허용된 세션만 명시적으로 로그아웃 처리한다. 단, 오프라인·타임아웃
            // 같은 전송 계층 실패는 토큰이 무효라는 근거가 아니므로 토큰을 지우지 않는다.
            // (지우면 네트워크 복구 후에도 소셜 로그인을 다시 해야 한다.)
            if canAutoLogin, !blockedByTransport {
                try? await repository.logout()
            }
            // 서버에 닿지도 못한 실패를 로그인 필요로 판정하면 유효한 세션이 있어도 로그인
            // 화면으로 밀려나므로, 판정 불가로 구분해 부트스트랩에서 재시도를 안내한다.
            return blockedByTransport ? .networkUnavailable : .notLoggedIn
        }
    }
}
