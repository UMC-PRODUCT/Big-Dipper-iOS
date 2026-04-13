//
//  LocationError.swift
//  UMCFoundation
//
//  Created by jaewon Lee on 1/6/26.
//

import Foundation

public enum LocationError: LocalizedError {
    case notAuthorized
    case locationFailed(String)
    case timeout
    case geocodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "위치 권한이 필요합니다."
        case .locationFailed(let message):
            return "위치를 가져올 수 없습니다. \(message)"
        case .timeout:
            return "위치 요청 시간이 초과되었습니다."
        case .geocodingFailed(let message):
            return "주소를 가져올 수 없습니다. \(message)"
        }
    }
}
