//
//  ScheduleCapabilitiesRepository.swift
//  HomeData
//
//  Created by euijjang97 on 8/9/26.
//

import CoreNetwork
import Foundation
import HomeDomain
import UMCFoundation

/// 일정 생성/수정 권한 조회 Repository 구현체
public final class ScheduleCapabilitiesRepository: ScheduleCapabilitiesRepositoryProtocol,
    @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any HomeNetworkRequesting

    // MARK: - Init

    /// 운영(DI) 진입점.
    public convenience init(adapter: MoyaNetworkAdapter) {
        self.init(networkRequesting: adapter)
    }

    /// 네트워크 추상화를 직접 주입하는 지정 이니셜라이저 (모듈 내부 · 테스트 전용).
    init(networkRequesting: any HomeNetworkRequesting) {
        self.networkRequesting = networkRequesting
    }

    // MARK: - Function

    /// 현재 사용자의 일정 생성/수정 권한을 조회한다.
    public func fetchCapabilities() async throws -> ScheduleCapabilities {
        let response = try await networkRequesting.request(ScheduleV2Router.getCapabilities)

        do {
            let apiResponse = try JSONDecoder().decode(
                APIResponse<ScheduleCapabilitiesDTO>.self,
                from: response.data
            )
            return try apiResponse.unwrap().toDomain()
        } catch let decodingError as DecodingError {
            #if DEBUG
            print(
                "[ScheduleCapabilitiesRepository] fetchCapabilities error=\(decodingError)"
            )
            #endif
            throw RepositoryError.decodingError(detail: "\(decodingError)")
        }
    }
}
