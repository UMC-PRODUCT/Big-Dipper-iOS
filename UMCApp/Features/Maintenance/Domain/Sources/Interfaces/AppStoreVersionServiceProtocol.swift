//
//  AppStoreVersionServiceProtocol.swift
//  MaintenanceDomain
//
//  Created by euijjang97 on 8/9/26.
//

/// App Store에 게시된 최신 버전을 제공하는 서비스 인터페이스.
public protocol AppStoreVersionServiceProtocol {
    /// 스토어 최신 버전 문자열을 조회한다. 조회에 실패하면 `nil`을 반환한다(fail-open).
    func fetchLatestVersion() async -> String?
}
