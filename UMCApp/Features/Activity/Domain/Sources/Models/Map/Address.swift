//
//  Address.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// 주소 정보
///
/// 지오코딩 결과로 얻은 주소를 전체/시/구 단위로 구분하여 저장합니다.
public struct Address: Equatable {
    public let fullAddress: String
    public let city: String
    public let district: String

    public init(fullAddress: String, city: String, district: String) {
        self.fullAddress = fullAddress
        self.city = city
        self.district = district
    }
}
