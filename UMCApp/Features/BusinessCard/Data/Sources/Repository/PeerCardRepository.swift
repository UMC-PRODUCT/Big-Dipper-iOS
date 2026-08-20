//
//  PeerCardRepository.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import Foundation
import Moya
import CoreNetwork
import CoreDomain
import UMCFoundation
import BusinessCardDomain

/// 상대 명함 조회 저장소 — QR 딥링크(`umc://card/{memberId}`) 스캔 전용.
///
/// 서버는 `/member/me`와 `/member/profile/{memberId}`에 **같은 응답 스키마**를 쓰고,
/// 타인 경로만 `toPublic()`으로 email·상벌점을 지운다. 그래서 내 명함이 쓰는 변환 체인
/// (``MemberProfileResponseDTO/toDomain()`` → ``Profile/toMyCard()``)을 그대로 재사용한다.
///
/// - Important: 응답에 `roles`·`challengerRecords`가 비어 있으면 변환이 **에러 없이**
///   `part = .admin`, `generation = "0"`으로 무너진다. 서버 마스킹 정책이 바뀌면 조용히
///   잘못된 명함이 저장되므로, 계약 테스트가 이 케이스를 고정한다.
public final class PeerCardRepository: PeerCardRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let networkRequesting: any BusinessCardNetworkRequesting
    private let decoder = JSONDecoder()

    // MARK: - Init

    /// 운영 이니셜라이저.
    public convenience init(adapter: MoyaNetworkAdapter) {
        self.init(networkRequesting: adapter)
    }

    /// 테스트 seam 주입용 (baseURL fatalError 회피 — ``ActivityStatRepository`` 선례).
    init(networkRequesting: any BusinessCardNetworkRequesting) {
        self.networkRequesting = networkRequesting
    }

    // MARK: - Function

    public func fetchCard(memberId: String) async throws -> MyCard {
        guard !memberId.isEmpty else {
            throw AppError.unknown(message: "명함 링크에 회원 식별자가 없습니다.")
        }

        let response = try await networkRequesting.request(
            BusinessCardRouter.getMemberProfile(memberId: memberId)
        )
        let dto: MemberProfileResponseDTO = try decodeAbsorbingWrapper(from: response.data)
        return dto.toDomain().toMyCard()
    }

    // MARK: - Private Function

    /// `APIResponse` 래핑·raw 양쪽 응답을 흡수한다 (``ActivityStatRepository`` 선례).
    private func decodeAbsorbingWrapper<T: Codable>(from data: Data) throws -> T {
        if let wrapped = try? decoder.decode(APIResponse<T>.self, from: data),
           let result = try? wrapped.unwrap() {
            return result
        }
        return try decoder.decode(T.self, from: data)
    }
}
