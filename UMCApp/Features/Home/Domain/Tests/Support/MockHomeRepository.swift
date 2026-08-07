//
//  MockHomeRepository.swift
//  HomeDomainTests
//
//  Created by euijjang97 on 7/9/26.
//

import Foundation
@testable import HomeDomain

/// UseCase 위임 테스트에서 공용으로 던지는 센티넬 에러
///
/// repository가 던진 에러가 UseCase를 통해 그대로 전파되는지 확인할 때 사용합니다.
enum HomeTestError: Error, Equatable {
    case boom
}

/// `HomeRepositoryProtocol`의 테스트용 Mock 구현체
///
/// 호출 횟수를 기록하고(`fetchMyProfileCallCount`), 반환/던질 값을 주입할 수 있습니다
/// (`fetchMyProfileResult`).
final class MockHomeRepository: HomeRepositoryProtocol, @unchecked Sendable {

    enum MockError: Error, Equatable {
        /// 테스트가 반환값을 주입하지 않은 메서드가 호출됨
        case notStubbed
    }

    var fetchMyProfileResult: Result<HomeProfileResult, Error> = .failure(MockError.notStubbed)
    private(set) var fetchMyProfileCallCount = 0
    private(set) var fetchMyProfileReceivedForceRefresh: Bool?

    var registerFCMTokenResult: Result<Void, Error> = .success(())
    private(set) var registerFCMTokenCallCount = 0
    private(set) var registerFCMTokenReceivedToken: String?

    func fetchMyProfile(forceRefresh: Bool) async throws -> HomeProfileResult {
        fetchMyProfileCallCount += 1
        fetchMyProfileReceivedForceRefresh = forceRefresh
        return try fetchMyProfileResult.get()
    }

    func registerFCMToken(fcmToken: String) async throws {
        registerFCMTokenCallCount += 1
        registerFCMTokenReceivedToken = fcmToken
        try registerFCMTokenResult.get()
    }
}
