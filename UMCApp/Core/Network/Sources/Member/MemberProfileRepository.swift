//
//  MemberProfileRepository.swift
//  CoreNetwork
//
//  Created by euijjang97 on 7/10/26.
//

import CoreDomain
import Foundation

/// 정본 내 프로필 조회 Repository 구현체.
public final class MemberProfileRepository: MemberProfileRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let decoder: JSONDecoder

    // MARK: - Init

    public init(adapter: MoyaNetworkAdapter, decoder: JSONDecoder = JSONDecoder()) {
        self.adapter = adapter
        self.decoder = decoder
    }

    // MARK: - Function

    public func fetchMyProfile() async throws -> Profile {
        let response = try await adapter.request(MemberProfileRouter.getMyProfile)
        let apiResponse = try decoder.decode(
            APIResponse<MemberProfileResponseDTO>.self,
            from: response.data
        )
        let dto = try apiResponse.unwrap()
        return dto.toDomain()
    }
}
