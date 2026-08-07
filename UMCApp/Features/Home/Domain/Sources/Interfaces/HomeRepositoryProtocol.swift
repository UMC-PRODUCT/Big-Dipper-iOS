//
//  HomeRepositoryProtocol.swift
//  HomeDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 홈 화면 프로필 관련 데이터 접근 계층 인터페이스.
public protocol HomeRepositoryProtocol {

    /// 홈 화면(시즌/세대 카드) 구성에 필요한 내 프로필을 조회한다.
    /// - Parameter forceRefresh: `true`이면 세션 프로필 캐시를 우회해 서버에서 새로 조회한다.
    func fetchMyProfile(forceRefresh: Bool) async throws -> HomeProfileResult

    /// 푸시 알림 수신을 위한 FCM 토큰을 서버에 등록/갱신한다.
    /// - Parameter fcmToken: Firebase Cloud Messaging 토큰
    func registerFCMToken(fcmToken: String) async throws
}

extension HomeRepositoryProtocol {

    /// 홈 화면(시즌/세대 카드) 구성에 필요한 내 프로필을 조회한다 (캐시 허용 기본 경로).
    public func fetchMyProfile() async throws -> HomeProfileResult {
        try await fetchMyProfile(forceRefresh: false)
    }
}
