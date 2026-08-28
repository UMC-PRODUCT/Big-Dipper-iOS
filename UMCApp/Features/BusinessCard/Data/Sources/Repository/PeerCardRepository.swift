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
/// - Important: 응답에 `roles`·`challengerRecords`가 비어 있으면 기수를 세울 근거가 없다.
///   예전에는 그 자리를 `part = .admin`, `generation = "0"`으로 메워 「운영진 · 0기」 명함이
///   에러 없이 저장됐다. 지금은 ``MyCard/validate()``가 그 응답을 실패로 돌린다 (#1223) —
///   근본 원인인 「명함 전용 공개 API 부재」는 서버 협의가 남아 있다.
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
        return try dto.toDomain().toMyCard()
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
