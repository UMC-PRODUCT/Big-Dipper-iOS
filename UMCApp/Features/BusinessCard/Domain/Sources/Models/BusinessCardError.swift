//
//  BusinessCardError.swift
//  BusinessCardDomain
//
//  Created by euijjang97 on 8/28/26.
//

import Foundation
import CoreNearbyExchange
import UMCFoundation

/// 명함 도메인 에러.
///
/// 이 타입이 없던 동안 교환 실패는 전부 `Bool` 한 칸으로 뭉개졌고, 화면은 원인과 무관하게
/// 「로컬 네트워크 권한을 켜 주세요」를 띄웠다. 5분이 정상적으로 지났을 뿐인 사용자도,
/// 명함첩 저장이 실패한 사용자도 같은 안내를 받았다.
///
/// 사유를 나누는 기준은 **사용자가 할 수 있는 행동**이다 — 설정을 열지, 다시 찾을지,
/// 그대로 재시도할지가 케이스마다 다르다.
public enum BusinessCardError: Error, LocalizedError, Equatable, Sendable {

    /// 로컬 네트워크 권한 거부. 설정을 열기 전에는 무엇을 해도 풀리지 않는다.
    case permissionDenied

    /// idle 시간이 다 됐다. 실패가 아니라 정상 종료라 문구도 달라야 한다.
    case sessionExpired

    /// 광고·탐색·전송이 서지 못했다. 원문은 진단용이라 그대로 문구에 싣지 않는다.
    case exchangeFailed(reason: String)

    /// 받은 명함을 명함첩에 넣지 못했다. 교환 자체는 성공했으므로 재시도가 의미 있다.
    case saveFailed(reason: String)

    /// 명함 링크에 회원 식별자가 없다 (QR·딥링크 파손).
    case invalidCardLink

    /// 상대가 이미 자리를 떠났다. 재시도해도 같은 결과라 문구가 달라야 한다.
    case peerUnavailable

    // MARK: - Init

    /// transport 에러를 도메인 언어로 옮긴다.
    ///
    /// 피처 레이어가 `NearbyError` 를 그대로 화면까지 들고 가면 MPC 를 다른 transport 로
    /// 바꾸는 순간 화면 문구가 통째로 깨진다.
    public init(_ error: NearbyError) {
        switch error {
        case .permissionDenied:
            self = .permissionDenied
        case .peerUnavailable:
            self = .peerUnavailable
        case .sessionExpired:
            self = .sessionExpired
        case .unsupported(let detail), .invalidPayload(let detail):
            self = .exchangeFailed(reason: detail)
        case .transportFailure(let underlying):
            self = .exchangeFailed(reason: underlying.localizedDescription)
        }
    }

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "설정에서 이 앱의 로컬 네트워크 권한을 켜 주세요."
        case .sessionExpired:
            return "한동안 아무도 만나지 못해 교환을 멈췄어요."
        case .exchangeFailed:
            return "주변 기기와 연결하지 못했어요. 두 기기를 가까이 두고 다시 시도해 주세요."
        case .saveFailed:
            return "받은 명함을 저장하지 못했어요. 다시 시도해 주세요."
        case .invalidCardLink:
            return "명함 링크에 회원 정보가 없어요."
        case .peerUnavailable:
            return "상대가 자리를 떠난 것 같아요. 다시 찾아 주세요."
        }
    }

    /// 진단용 원문. 사용자 문구에는 싣지 않는다.
    public var diagnosticReason: String? {
        switch self {
        case .exchangeFailed(let reason), .saveFailed(let reason):
            return reason
        case .permissionDenied, .sessionExpired, .invalidCardLink, .peerUnavailable:
            return nil
        }
    }

    /// `Loadable` 은 `AppError` 만 받는다. 사유를 잃지 않고 얹기 위한 다리다.
    public var asAppError: AppError {
        .domain(.custom(message: errorDescription ?? ""))
    }
}
