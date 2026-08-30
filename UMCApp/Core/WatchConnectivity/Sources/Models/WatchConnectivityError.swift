//
//  WatchConnectivityError.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 4/24/26.
//

import Foundation

/// 기기 간 통신에서 나올 수 있는 실패.
///
/// `WCError` 코드 분류는 ``WatchSessionCoordinator`` 파일의 `from(_:)` 이 맡는다 —
/// 이 파일이 `WatchConnectivity` 를 import 하면 계약·코덱 계층 전체가 프레임워크에 묶여
/// `WCSession` 을 활성화할 수 없는 유닛 테스트에서 검증 불가능해진다.
public enum WatchConnectivityError: Error {

    /// `WCSession.isSupported() == false` (iPad 등).
    case notSupported
    case sessionNotActivated
    /// `sendMessage` 전용 — 즉시 채널만 reachable 을 요구한다.
    case notReachable
    /// 페이로드가 너무 크다 (7009). 호출자는 스냅샷 건수를 줄여야 한다.
    case payloadTooLarge
    /// 상대가 제때 응답하지 않았다 (7012). 호출자는 재시도하거나 큐로 넘긴다.
    case replyTimedOut
    /// 봉투를 읽을 수 없다.
    case malformedPayload(String)
    /// 지원하지 않는 스키마 버전.
    case unsupportedSchemaVersion(Int)
    /// 요청한 종류와 다른 응답이 왔다.
    case unexpectedReply(WatchReply)
    /// 이 채널로는 보낼 수 없는 종류다 — **호출자 오류**이며 상대의 거절(``remote(_:)``)과 다르다.
    case unsupportedChannel(WatchMessage)
    /// 상대가 처리에 실패했다고 응답했다.
    case remote(WatchRemoteFailure)
    case transportFailure(underlying: Error)
}
