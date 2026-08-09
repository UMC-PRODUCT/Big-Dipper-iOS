//
//  StubAppStoreVersionService.swift
//  MaintenanceDomainTests
//
//  Created by euijjang97 on 8/9/26.
//

@testable import MaintenanceDomain

/// `AppStoreVersionServiceProtocol`의 테스트용 Stub 구현체
///
/// 실제 iTunes Lookup 호출 없이 고정된 버전 문자열을 반환한다.
final class StubAppStoreVersionService: AppStoreVersionServiceProtocol, @unchecked Sendable {

    var stubbedLatestVersion: String?

    init(stubbedLatestVersion: String? = nil) {
        self.stubbedLatestVersion = stubbedLatestVersion
    }

    func fetchLatestVersion() async -> String? {
        stubbedLatestVersion
    }
}
