//
//  ScheduleCapabilitiesRepository.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import Foundation
import Moya

/// `ScheduleCapabilitiesRepositoryProtocol` 구현체
///
/// `ScheduleV2Router` 를 통해 `/api/v2/schedules/capabilities` 를 호출하고
/// 응답 DTO 를 도메인 모델로 변환해 반환합니다.
///
/// - SeeAlso: ``ScheduleCapabilitiesRepositoryProtocol``, ``ScheduleV2Router``
final class ScheduleCapabilitiesRepository: ScheduleCapabilitiesRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let decoder: JSONDecoder

    // MARK: - Init

    init(
        adapter: MoyaNetworkAdapter,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.adapter = adapter
        self.decoder = decoder
    }

    // MARK: - Function

    func fetchCapabilities() async throws -> ScheduleCapabilities {
        let response = try await adapter.request(ScheduleV2Router.getCapabilities)
        let apiResponse = try decoder.decode(
            APIResponse<ScheduleCapabilitiesDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap().toDomain()
    }
}
