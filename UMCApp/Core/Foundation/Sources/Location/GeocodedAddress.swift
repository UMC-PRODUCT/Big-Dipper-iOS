//
//  GeocodedAddress.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 1/6/26.
//

import Foundation

/// 역지오코딩 결과를 손실 없이 담는 Core 값 타입
///
/// Core는 Feature 모듈(`ActivityDomain`)의 `Address`에 의존할 수 없으므로, MapKit이 제공하는
/// 구조화된 주소 필드를 그대로 보존해 반환합니다. Feature 어댑터(#992 Phase B)가 이 값을
/// `Address`로 변환합니다.
///
/// - Note: `city`/`district`는 MapKit(iOS 26) `MKAddressRepresentations`의 `regionName`/
///   `cityName`에서 옵니다. 미국식 지역 체계(도시/주) 기준이라 한국 주소의 시/구와 정확히
///   1:1 대응하지 않을 수 있어, 실제 화면 표기에 맞는 매핑은 어댑터에서 검증이 필요합니다.
public struct GeocodedAddress: Equatable, Sendable {
    public let fullAddress: String
    public let shortAddress: String?
    public let city: String?
    public let district: String?

    public init(fullAddress: String, shortAddress: String?, city: String?, district: String?) {
        self.fullAddress = fullAddress
        self.shortAddress = shortAddress
        self.city = city
        self.district = district
    }
}
