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
