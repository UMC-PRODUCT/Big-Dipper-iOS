//
//  BusinessCardNetworkRequesting.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import Foundation
import CoreNetwork
import Moya

/// Repository 단위 테스트용 네트워크 요청 seam (MyPageNetworkRequesting 선례).
///
/// 운영 채택 타입은 `MoyaNetworkAdapter` 하나. 인증 요청만 필요해 `request`만 요구한다.
/// 테스트 목적 추상화로 런타임 동작에는 영향이 없다 (baseURL fatalError 회피).
protocol BusinessCardNetworkRequesting {
    func request<T: TargetType>(_ target: T) async throws -> Response
}

extension MoyaNetworkAdapter: BusinessCardNetworkRequesting {}

// MARK: - Envelope Absorbing Decode

extension JSONDecoder {

    /// `APIResponse` 래핑 응답과 raw 응답을 **양쪽 다** 흡수한다.
    ///
    /// 서버가 같은 자원을 어떤 컨트롤러에서는 봉투에 싸고 어떤 곳에서는 그대로 내려서,
    /// 호출부마다 한쪽만 가정하면 그때그때 깨진다 (`MyPageRepository.fetchMemberProfile`
    /// 선례). 이 피처의 저장소가 전부 이 한 규칙을 쓴다.
    func decodeAbsorbingWrapper<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        if let wrapped = try? decode(APIResponse<T>.self, from: data),
           let result = try? wrapped.unwrap() {
            return result
        }
        return try decode(T.self, from: data)
    }
}
