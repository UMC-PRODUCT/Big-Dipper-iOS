//
//  Coordinate.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 4/14/26.
//

import Foundation

/// 위경도 좌표
///
/// GPS 출석, 지도 표시 등에서 사용하는 위치 좌표 값 타입입니다.
public struct Coordinate: Hashable, Codable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
