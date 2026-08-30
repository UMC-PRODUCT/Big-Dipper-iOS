//
//  HomeRouterTests.swift
//  HomeDataTests
//

import Foundation
import Testing
import Moya
@testable import HomeData

// MARK: - Helpers

private func makeFCMInstallation() -> HomeRouter {
    HomeRouter.postFCMInstallation(
        installationId: "8B1F4C2E-0000-4000-8000-000000000001",
        fcmToken: "fcm-token-abc",
        platform: "iOS",
        appVersion: "2.2.0"
    )
}

private func encodeToJSON(_ value: some Encodable) throws -> [String: Any] {
    let data = try JSONEncoder().encode(value)
    let obj = try JSONSerialization.jsonObject(with: data)
    return try #require(obj as? [String: Any])
}

// MARK: - Suite: path / method

@Suite("HomeRouter — path/method 계약")
struct HomeRouterPathMethodTests {

    // MARK: - getGisuDetail

    @Test("getGisuDetail — gisuId '7'이 path에 보간됨")
    func getGisuDetailPathInterpolation() {
        #expect(HomeRouter.getGisuDetail(gisuId: "7").path == "/api/v1/gisu/7")
    }

    @Test("getGisuDetail — method가 .get")
    func getGisuDetailMethod() {
        #expect(HomeRouter.getGisuDetail(gisuId: "7").method == .get)
    }

    // MARK: - postFCMInstallation

    /// 옛 경로 `PUT /api/v1/notification/fcm/token` 은 서버에서 제거돼 404를 반환했고,
    /// 그 탓에 이 기기로 어떤 푸시도 도착하지 않았다. 이 두 테스트가 그 회귀를 막는 장치다.
    @Test("postFCMInstallation — path가 /api/v1/notifications/fcm/installations")
    func postFCMInstallationPath() {
        #expect(makeFCMInstallation().path == "/api/v1/notifications/fcm/installations")
    }

    @Test("postFCMInstallation — method가 .post")
    func postFCMInstallationMethod() {
        #expect(makeFCMInstallation().method == .post)
    }
}

// MARK: - Suite: task shape

@Suite("HomeRouter — task 형태 계약")
struct HomeRouterTaskTests {

    @Test("getGisuDetail — task가 .requestPlain")
    func getGisuDetailTask() {
        if case .requestPlain = HomeRouter.getGisuDetail(gisuId: "7").task {
            // 기대하는 case
        } else {
            Issue.record("task가 .requestPlain 여야 함")
        }
    }

    @Test("postFCMInstallation — 바디에 서버가 요구하는 네 필드가 그대로 실림")
    func postFCMInstallationTaskBody() throws {
        guard case let .requestJSONEncodable(body) = makeFCMInstallation().task else {
            Issue.record("task가 .requestJSONEncodable 여야 함")
            return
        }

        let json = try encodeToJSON(body)
        #expect(json.count == 4)
        #expect(json["installationId"] as? String == "8B1F4C2E-0000-4000-8000-000000000001")
        #expect(json["fcmToken"] as? String == "fcm-token-abc")
        #expect(json["platform"] as? String == "iOS")
        #expect(json["appVersion"] as? String == "2.2.0")
    }
}
