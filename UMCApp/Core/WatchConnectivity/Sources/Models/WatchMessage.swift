//
//  WatchMessage.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 8/29/26.
//

import Foundation

/// WCSession 위로 오가는 메시지 봉투.
///
/// 봉투를 두는 이유는 **같은 채널에 여러 종류가 섞여 흐르기 때문**이다. 수신 측이 `kind` 로
/// 갈라내지 못하면 읽음 확인을 출석 요청으로 오인한다.
public enum WatchMessage: Codable, Sendable, Equatable {

    // MARK: - Watch → iPhone

    /// GPS 출석 요청. 온라인이면 왕복(``WatchReply/attendance(_:)``), 오프라인이면 큐잉된다.
    case attendanceRequest(WatchAttendanceRequest)
    /// 공지 읽음 확인. 단방향 — `transferUserInfo` 로만 보낸다.
    case noticeRead(WatchNoticeRead)
    /// 최신 스냅샷 요청. 응답은 ``WatchReply/state(_:)``.
    case syncRequest

    // MARK: - iPhone → Watch

    /// 최신 스냅샷 밀어넣기. `updateApplicationContext` 로만 보낸다.
    case sessionState(WatchSessionState)
    /// 출석 결과가 **방금 바뀌었다**는 이벤트 (`ATTENDANCE_STATUS_CHANGED` 푸시 반영).
    ///
    /// ``sessionState(_:)`` 안의 `attendanceStatus` 와 값이 겹치지만 의미가 다르다 —
    /// 상태는 배지를, 이벤트는 결과 화면 전환을 만든다.
    case attendanceChanged(WatchAttendanceResult)

    // MARK: - Codable

    private enum CodingKeys: String, CodingKey {
        case kind
        case version
        case attendanceRequest
        case noticeRead
        case sessionState
        case attendanceChanged
    }

    private enum Kind: String, Codable {
        case attendanceRequest
        case noticeRead
        case syncRequest
        case sessionState
        case attendanceChanged
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard (1...WatchSchema.currentVersion).contains(version) else {
            throw WatchConnectivityError.unsupportedSchemaVersion(version)
        }

        // 모르는 kind 는 `decode(Kind.self)` 가 그대로 던진다. 워치와 폰은 서로 다른 시점에
        // 업데이트되므로, 모르는 종류를 조용히 삼키면 어디서도 걸리지 않는다.
        switch try container.decode(Kind.self, forKey: .kind) {
        case .attendanceRequest:
            self = .attendanceRequest(
                try container.decode(WatchAttendanceRequest.self, forKey: .attendanceRequest)
            )
        case .noticeRead:
            self = .noticeRead(try container.decode(WatchNoticeRead.self, forKey: .noticeRead))
        case .syncRequest:
            self = .syncRequest
        case .sessionState:
            self = .sessionState(
                try container.decode(WatchSessionState.self, forKey: .sessionState)
            )
        case .attendanceChanged:
            self = .attendanceChanged(
                try container.decode(WatchAttendanceResult.self, forKey: .attendanceChanged)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(WatchSchema.currentVersion, forKey: .version)
        switch self {
        case .attendanceRequest(let request):
            try container.encode(Kind.attendanceRequest, forKey: .kind)
            try container.encode(request, forKey: .attendanceRequest)
        case .noticeRead(let read):
            try container.encode(Kind.noticeRead, forKey: .kind)
            try container.encode(read, forKey: .noticeRead)
        case .syncRequest:
            try container.encode(Kind.syncRequest, forKey: .kind)
        case .sessionState(let state):
            try container.encode(Kind.sessionState, forKey: .kind)
            try container.encode(state, forKey: .sessionState)
        case .attendanceChanged(let result):
            try container.encode(Kind.attendanceChanged, forKey: .kind)
            try container.encode(result, forKey: .attendanceChanged)
        }
    }
}
