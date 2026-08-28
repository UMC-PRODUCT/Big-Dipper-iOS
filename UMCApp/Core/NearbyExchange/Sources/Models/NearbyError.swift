//
//  NearbyError.swift
//  CoreNearbyExchange
//
//  Created by euijjang97 on 4/23/26.
//

import Foundation

public enum NearbyError: Error, Sendable {
    case permissionDenied
    /// 목록에 있던 피어가 이미 사라졌다.
    ///
    /// 재시도하면 안 되는 실패다 — MPC 는 없는 기기에게도 초대를 걸고 연결
    /// 타임아웃(20초)을 통째로 태운 뒤에야 실패한다. 재시도 3회면 1분을 버린다.
    case peerUnavailable
    case unsupported(String)
    case invalidPayload(String)
    case transportFailure(underlying: Error)
    case sessionExpired

    public var localizedDescription: String {
        switch self {
        case .permissionDenied:
            return "근거리 교환에 필요한 권한이 거부되었습니다."
        case .peerUnavailable:
            return "상대 기기를 더 이상 찾을 수 없습니다."
        case .unsupported(let detail):
            return "이 기기에서는 지원하지 않는 기능입니다: \(detail)"
        case .invalidPayload(let detail):
            return "잘못된 페이로드 형식입니다: \(detail)"
        case .transportFailure(let underlying):
            return "전송 중 오류가 발생했습니다: \(underlying.localizedDescription)"
        case .sessionExpired:
            return "교환 세션이 만료되었습니다."
        }
    }
}

// MARK: - Classification

extension NearbyError {

    /// mDNS 가 권한 거부에 쓰는 원본 코드(`kDNSServiceErr_PolicyDenied`).
    ///
    /// `NetService` 상수를 쓰면 deprecation 경고가 나므로 값과 키 문자열을 직접 든다.
    private static let policyDeniedCode = -65570
    private static let netServicesDomain = "NSNetServicesErrorDomain"
    private static let netServicesCodeKey = "NSNetServicesErrorCode"

    /// 광고·탐색이 서지 못한 원인을 분류한다.
    ///
    /// 로컬 네트워크 권한이 거부돼도 MultipeerConnectivity 는 권한 API 로 알려 주지 않는다 —
    /// Bonjour 실패로 위장해 `NSNetServicesErrorDomain` 에 mDNS 원본 코드를 실어 온다.
    /// 그 조합일 때만 권한으로 판정하고 나머지는 원문을 그대로 들고 올라간다. 뭉뚱그려
    /// 권한 문제로 단정하면 「설정에서 권한을 켜라」는 틀린 안내를 하게 된다.
    ///
    /// - Note: 실기기 검증 필요 — 시뮬레이터는 로컬 네트워크 권한 자체를 묻지 않는다.
    public static func startFailure(_ error: any Error) -> NearbyError {
        let nsError = error as NSError
        guard nsError.domain == netServicesDomain,
              let code = nsError.userInfo[netServicesCodeKey] as? Int,
              code == policyDeniedCode
        else {
            return .transportFailure(underlying: error)
        }
        return .permissionDenied
    }
}
