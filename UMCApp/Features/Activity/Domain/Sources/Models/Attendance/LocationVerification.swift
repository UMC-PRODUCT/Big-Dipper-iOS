//
//  LocationVerification.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// GPS 출석 위치 인증 결과
///
/// 사용자의 GPS 좌표가 세션 장소 지오펜스 내에 있는지 검증한 결과를 담습니다.
public struct LocationVerification: Equatable {
    public let isVerified: Bool
    public let coordinate: Coordinate
    public let address: Address
    public let verifiedAt: Date

    public init(
        isVerified: Bool,
        coordinate: Coordinate,
        address: Address,
        verifiedAt: Date
    ) {
        self.isVerified = isVerified
        self.coordinate = coordinate
        self.address = address
        self.verifiedAt = verifiedAt
    }
}
