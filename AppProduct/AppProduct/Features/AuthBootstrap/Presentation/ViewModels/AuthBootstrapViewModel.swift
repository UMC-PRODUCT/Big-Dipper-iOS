//
//  AuthBootstrapViewModel.swift
//  AppProduct
//
//  Created by euijjang97 on 5/26/26.
//
//  앱 진입 시 부트스트랩 ViewModel — 앱스토어 강제 업데이트 검사 + 토큰 검증/리프레시 + 프로필
//  fetch + 인증 상태 판정. 뷰 측의 시네마틱 진행과는 완전 독립적으로 동작한다.
//

import Foundation
import UIKit

/// 앱 부트스트랩 ViewModel — 토큰/프로필/버전을 검사하고 인증 상태를 판정한다.
///
/// 시간 의존성 없음. 뷰 측이 시네마틱 하한선을 별도로 기다리고, 본 ViewModel 은
/// 외부 IO 가 끝나는 대로 `authStatus` 를 채운다.
@Observable
final class AuthBootstrapViewModel {

    // MARK: - Property

    private let networkClient: NetworkClient
    private let fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol
    private let tokenStore: TokenStore

    /// 인증 상태 검사 완료 여부
    private(set) var isCheckComplete = false

    /// 앱 업데이트 필요 여부
    private(set) var needsUpdate = false

    /// 강제 업데이트 Alert
    var updateAlertPrompt: AlertPrompt?

    /// 부트스트랩 인증 판정 결과
    private(set) var authStatus: AuthBootstrapStatus = .notLoggedIn
    /// 디버그 표시용 액세스 토큰 문자열
    private(set) var debugAccessToken: String = "(nil)"
    /// 디버그 표시용 리프레시 토큰 문자열
    private(set) var debugRefreshToken: String = "(nil)"

    fileprivate enum Constants {
        static let appStoreID = "6759412446"
        static let lookupURLString = "https://itunes.apple.com/lookup?bundleId=com.umc.product&country=kr"
        static let appStoreURLString = "https://apps.apple.com/us/app/umc/id\(appStoreID)"
    }

    // MARK: - Init

    init(
        networkClient: NetworkClient,
        fetchMyProfileUseCase: FetchMyProfileUseCaseProtocol,
        tokenStore: TokenStore
    ) {
        self.networkClient = networkClient
        self.fetchMyProfileUseCase = fetchMyProfileUseCase
        self.tokenStore = tokenStore
    }

    // MARK: - Function

    /// 인증 상태 검사
    ///
    /// 앱 버전 검사와 토큰 검사를 background 에서 동시에 실행한다.
    /// 앱 업데이트가 필요한 경우 인증 검사를 완료하지 않고 업데이트 Alert 를 표시한다.
    @MainActor
    func checkAuthStatus() async {
        await updateDebugTokens()
        async let updateRequired = checkAppStoreVersion()
        async let resolvedStatus = resolveAuthStatus()

        if await updateRequired {
            needsUpdate = true
            showUpdateAlert()
            return
        }

        authStatus = await resolvedStatus
        await updateDebugTokens()
        isCheckComplete = true
    }

    /// 강제 업데이트 Alert 표시
    ///
    /// App Store 에서 돌아왔을 때 다시 표시하기 위해 별도 메서드로 분리.
    func showUpdateAlert() {
        updateAlertPrompt = AlertPrompt(
            title: "업데이트 안내",
            message: "새로운 버전이 출시되었습니다.\n최신 버전으로 업데이트해주세요.",
            positiveBtnTitle: "업데이트",
            positiveBtnAction: { [weak self] in
                self?.openAppStore()
            }
        )
    }

    /// App Store 로 이동
    private func openAppStore() {
        guard let url = URL(string: Constants.appStoreURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Private Function

    /// App Store Lookup API 를 호출하여 강제 업데이트가 필요한지 확인.
    ///
    /// Major.Minor 버전만 비교하여 마이너 버전 이상 변경 시에만 `true` 를 반환.
    /// (예: 1.2 → 1.3 강제 업데이트, 1.2.0 → 1.2.1 허용)
    /// API 호출 실패 시에는 `false` 를 반환하여 앱 진입을 차단하지 않는다.
    private func checkAppStoreVersion() async -> Bool {
        guard let url = URL(string: Constants.lookupURLString) else {
            return false
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(
                AppStoreLookupResult.self,
                from: data
            )
            guard let storeVersion = result.results.first?.version else {
                return false
            }
            let currentVersion = Bundle.main.infoDictionary?[
                "CFBundleShortVersionString"
            ] as? String ?? "0.0.0"

            let storeMajorMinor = majorMinor(from: storeVersion)
            let currentMajorMinor = majorMinor(from: currentVersion)

            return storeMajorMinor.compare(
                currentMajorMinor,
                options: .numeric
            ) == .orderedDescending
        } catch {
            return false
        }
    }

    /// 버전 문자열에서 Major.Minor 부분만 추출
    private func majorMinor(from version: String) -> String {
        let components = version.split(separator: ".")
        guard components.count >= 2 else { return version }
        return "\(components[0]).\(components[1])"
    }

    /// 토큰/프로필 기반으로 부트스트랩 인증 상태를 판정
    private func resolveAuthStatus() async -> AuthBootstrapStatus {
        let defaults = UserDefaults.standard
        let canAutoLogin = defaults.bool(
            forKey: AppStorageKey.canAutoLogin
        )
        let hasAccessToken = await networkClient.isLoggedIn()

        guard hasAccessToken else {
            return .notLoggedIn
        }

        // HomeDebug 스킴: 환경변수로 토큰 갱신 스킵
        let skipRefresh = ProcessInfo.processInfo
            .environment["SKIP_TOKEN_REFRESH"] != nil

        if !skipRefresh {
            // 앱 시작 시 토큰을 선행 갱신하여 이후 API 실패 가능성을 줄인다.
            do {
                _ = try await networkClient.forceRefreshToken()
            } catch {
                // 리프레시 실패 시에도 액세스 토큰으로 프로필 조회를 한 번 더 시도한다.
            }
        }

        do {
            let profile = try await fetchMyProfileUseCase.execute()
            let isApproved = isApprovedProfile(profile)
            if isApproved {
                if !canAutoLogin {
                    defaults.set(true, forKey: AppStorageKey.canAutoLogin)
                }
                return .approved
            }
            return canAutoLogin ? .pendingApproval : .notLoggedIn
        } catch {
            // 토큰은 있으나 프로필 조회 실패 시 로그인 화면으로 안전하게 폴백
            if canAutoLogin {
                try? await networkClient.logout()
            }
            return .notLoggedIn
        }
    }

    func isApprovedProfile(_ profile: HomeProfileResult) -> Bool {
        if !profile.generations.isEmpty {
            return true
        }

        for seasonType in profile.seasonTypes {
            if case .gens(let generations) = seasonType, !generations.isEmpty {
                return true
            }
        }

        return false
    }

    @MainActor
    func updateDebugTokens() async {
        debugAccessToken = await tokenStore.getAccessToken() ?? "(nil)"
        debugRefreshToken = await tokenStore.getRefreshToken() ?? "(nil)"
    }
}

// MARK: - AuthBootstrapStatus

/// 부트스트랩 인증 판정 상태
enum AuthBootstrapStatus {
    /// 정상 로그인 + 승인 완료
    case approved
    /// 토큰은 있으나 승인 대기 상태
    case pendingApproval
    /// 로그아웃 상태 혹은 인증 판정 실패
    case notLoggedIn
}

// MARK: - AppStoreLookupResult

/// App Store Lookup API 응답 모델
private struct AppStoreLookupResult: Decodable {
    let resultCount: Int
    let results: [AppStoreAppInfo]
}

/// App Store 앱 정보
private struct AppStoreAppInfo: Decodable {
    let version: String
}
