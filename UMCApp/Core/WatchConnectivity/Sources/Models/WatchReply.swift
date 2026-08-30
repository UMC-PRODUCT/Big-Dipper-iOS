//
//  WatchReply.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 8/29/26.
//

import Foundation

// MARK: - WatchReply

/// `replyHandler` 로 돌아가는 응답 봉투.
///
/// ``WatchMessage`` 와 **분리한 이유**: 응답은 요청받은 쪽만 만든다. 한 enum 으로 합치면
/// 출석 요청의 응답으로 `.noticeRead` 가 돌아오는 상태가 타입상 표현 가능해진다.
/// 두 방향을 나누면 그 상태 자체가 사라진다.
public enum WatchReply: Codable, Sendable, Equatable {

    /// 단방향 메시지의 수신 확인. 모든 `sendMessage` 가 `replyHandler` 를 넘기므로
    /// 응답이 필요 없는 메시지도 ack 를 돌려준다.
    case ack
    /// ``WatchMessage/syncRequest`` 의 응답.
    case state(WatchSessionState)
    /// ``WatchMessage/attendanceRequest(_:)`` 의 응답.
    case attendance(WatchAttendanceResult)
    /// 상대가 요청을 처리하지 못했다. **에러를 던지는 대신 응답으로 실어 보낸다** —
    /// 그러지 않으면 송신자는 WCSession 타임아웃(7012)만 보고 원인을 알 수 없다.
    case failure(WatchRemoteFailure)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case kind
        case version
        case state
        case attendance
        case failure
    }

    private enum Kind: String, Codable {
        case ack
        case state
        case attendance
        case failure
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard (1...WatchSchema.currentVersion).contains(version) else {
            throw WatchConnectivityError.unsupportedSchemaVersion(version)
        }

        switch try container.decode(Kind.self, forKey: .kind) {
        case .ack:
            self = .ack
        case .state:
            self = .state(try container.decode(WatchSessionState.self, forKey: .state))
        case .attendance:
            self = .attendance(
                try container.decode(WatchAttendanceResult.self, forKey: .attendance)
            )
        case .failure:
            self = .failure(try container.decode(WatchRemoteFailure.self, forKey: .failure))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(WatchSchema.currentVersion, forKey: .version)
        switch self {
        case .ack:
            try container.encode(Kind.ack, forKey: .kind)
        case .state(let state):
            try container.encode(Kind.state, forKey: .kind)
            try container.encode(state, forKey: .state)
        case .attendance(let result):
            try container.encode(Kind.attendance, forKey: .kind)
            try container.encode(result, forKey: .attendance)
        case .failure(let failure):
            try container.encode(Kind.failure, forKey: .kind)
            try container.encode(failure, forKey: .failure)
        }
    }
}

// MARK: - WatchRemoteFailure

/// 상대 기기가 요청을 처리하지 못한 사유.
public struct WatchRemoteFailure: Codable, Sendable, Equatable {

    // MARK: - Reason

    public enum Reason: String, Codable, Sendable {
        /// 봉투를 디코딩하지 못했다 (손상).
        case malformedPayload
        /// 상대가 우리보다 새로운 스키마를 쓴다. 손상과 달리 **업데이트가 필요하다**는 신호다.
        case unsupportedSchemaVersion
        /// 핸들러 미등록이거나 이 방향에서 받을 수 없는 종류다.
        case unsupportedRequest
        /// iPhone 이 로그아웃 상태다. 워치는 로그인 안내를 그린다.
        case notSignedIn
        /// iPhone 이 서버 호출에 실패했다.
        case upstreamFailed
    }

    // MARK: - Property

    public let reason: Reason
    /// 디버깅·표시용 보조 메시지. 사용자 문구는 워치가 `reason` 으로 고른다.
    public let message: String?

    // MARK: - Init

    public init(reason: Reason, message: String? = nil) {
        self.reason = reason
        self.message = message
    }
}
