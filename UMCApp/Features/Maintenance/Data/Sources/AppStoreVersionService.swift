//
//  AppStoreVersionService.swift
//  MaintenanceData
//
//  Created by euijjang97 on 8/9/26.
//

import Foundation
import MaintenanceDomain
import os

/// iTunes Lookup API로 App Store 게시 버전을 조회하는 서비스.
///
/// 스토어 조회는 강제 업데이트 판정의 보조 게이트라, URL 구성·네트워크·디코딩 중 어디서
/// 실패하든 `nil`을 반환해 앱 진입을 막지 않는다(fail-open).
public final class AppStoreVersionService: AppStoreVersionServiceProtocol {

    // MARK: - Constant

    private enum Constants {
        /// 스토어 게시 정보는 심사에 제출된 번들 식별자로만 조회되므로, 앱 타겟의
        /// 번들 ID와 별개로 스토어 등재 ID를 그대로 사용한다.
        static let lookupURLString =
            "https://itunes.apple.com/lookup?bundleId=com.umc.product&country=kr"
    }

    // MARK: - Property

    private let session: URLSession

    // MARK: - Init

    public init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Function

    public func fetchLatestVersion() async -> String? {
        guard let url = URL(string: Constants.lookupURLString) else { return nil }

        do {
            let (data, _) = try await session.data(from: url)
            let response = try JSONDecoder().decode(
                AppStoreLookupResponseDTO.self,
                from: data
            )
            guard let version = response.results.first?.version, !version.isEmpty else {
                return nil
            }
            return version
        } catch {
            Self.logger.error(
                "App Store Lookup 실패(통과 처리): \(error.localizedDescription, privacy: .public)"
            )
            return nil
        }
    }
}

// MARK: - Logging

extension AppStoreVersionService {
    private static let logger = Logger(
        subsystem: "dev.umc.feature.maintenance.data",
        category: "AppStoreVersionService"
    )
}
