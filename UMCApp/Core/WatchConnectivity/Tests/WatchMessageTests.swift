//
//  WatchMessageTests.swift
//  CoreWatchConnectivityTests
//
//  Created by euijjang97 on 8/29/26.
//

import Foundation
import Testing
@testable import CoreWatchConnectivity

/// iOS ↔ watchOS 사이를 오가는 봉투의 계약.
///
/// 다섯 종류가 **같은 채널**에 섞여 흐르므로, 디코딩이 종류를 갈라내지 못하면 읽음 확인이
/// 출석 요청으로 오인된다. 두 기기가 서로 다른 시점에 업데이트되는 것도 여기서 고정한다.
@Suite("WatchMessage — 봉투 왕복")
struct WatchMessageTests {

    // MARK: - Fixture

    /// 날짜를 정수 초로 고정한다.
    ///
    /// 전송 포맷이 ISO8601 이라 소수점 이하 초가 인코딩에서 잘린다. `Date()` 기본값을 쓰면
    /// 왕복 후 마이크로초가 어긋나 동등 비교가 실패한다 — 봉투의 결함이 아니라 날짜 표현의
    /// 성질이므로, 그 성질을 피해서 봉투만 검증한다.
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeRequest() -> WatchAttendanceRequest {
        WatchAttendanceRequest(
            scheduleId: "42",
            latitude: 37.557_192,
            longitude: 127.045_5,
            locationVerified: true,
            measuredAt: fixedDate
        )
    }

    private func makeNotice() -> WatchNotice {
        WatchNotice(
            noticeId: "7",
            title: "5주차 세미나 공지",
            content: "이번 주 세미나는 온라인으로 진행합니다.",
            writer: "정의찬",
            postedAt: fixedDate,
            isMustRead: true,
            isAlert: false,
            isRead: false
        )
    }

    private func makeSchedule(location: WatchScheduleLocation?) -> WatchSchedule {
        WatchSchedule(
            scheduleId: "42",
            name: "5주차 세미나",
            startsAt: fixedDate,
            endsAt: fixedDate.addingTimeInterval(7_200),
            location: location,
            attendanceWindow: location.map { _ in
                WatchAttendanceWindow(
                    checkInStartAt: fixedDate.addingTimeInterval(-600),
                    onTimeEndAt: fixedDate.addingTimeInterval(600),
                    lateEndAt: fixedDate.addingTimeInterval(1_800)
                )
            },
            attendanceStatus: location == nil ? nil : "PENDING"
        )
    }

    private func makeState() -> WatchSessionState {
        WatchSessionState(
            isSignedIn: true,
            schedules: [
                makeSchedule(
                    location: WatchScheduleLocation(
                        name: "한양대학교 IT/BT관",
                        latitude: 37.557_192,
                        longitude: 127.045_5
                    )
                ),
                makeSchedule(location: nil)
            ],
            notices: [makeNotice()],
            generatedAt: fixedDate
        )
    }

    private func makeResult(status: String) -> WatchAttendanceResult {
        WatchAttendanceResult(
            scheduleId: "42",
            status: status,
            decidedAt: fixedDate,
            reason: "병원 진료"
        )
    }

    private func roundtrip(_ message: WatchMessage) throws -> WatchMessage {
        try WatchEnvelope.jsonDecoder.decode(
            WatchMessage.self, from: WatchEnvelope.jsonEncoder.encode(message)
        )
    }

    private func kindTag(_ message: WatchMessage) -> String {
        switch message {
        case .attendanceRequest: "attendanceRequest"
        case .noticeRead: "noticeRead"
        case .syncRequest: "syncRequest"
        case .sessionState: "sessionState"
        case .attendanceChanged: "attendanceChanged"
        }
    }

    // MARK: - Roundtrip

    @Test("attendanceRequest 왕복 — 좌표·검증 결과·측정 시각이 보존된다")
    func attendanceRequestRoundtrip() throws {
        let request = makeRequest()

        guard case .attendanceRequest(let restored) = try roundtrip(.attendanceRequest(request))
        else {
            Issue.record("attendanceRequest 로 디코딩되지 않음"); return
        }
        #expect(restored == request)
        #expect(restored.measuredAt == request.measuredAt)
    }

    @Test("noticeRead 왕복 — 공지 식별자와 읽은 시각이 보존된다")
    func noticeReadRoundtrip() throws {
        let read = WatchNoticeRead(noticeId: "7", readAt: fixedDate)

        guard case .noticeRead(let restored) = try roundtrip(.noticeRead(read)) else {
            Issue.record("noticeRead 로 디코딩되지 않음"); return
        }
        #expect(restored == read)
    }

    @Test("syncRequest 왕복 — 연관값 없는 케이스가 kind 만으로 복원된다")
    func syncRequestRoundtrip() throws {
        guard case .syncRequest = try roundtrip(.syncRequest) else {
            Issue.record("syncRequest 로 디코딩되지 않음"); return
        }
    }

    @Test("sessionState 왕복 — 중첩 목록과 옵셔널 위치·출석 정책이 보존된다")
    func sessionStateRoundtrip() throws {
        let state = makeState()

        guard case .sessionState(let restored) = try roundtrip(.sessionState(state)) else {
            Issue.record("sessionState 로 디코딩되지 않음"); return
        }
        #expect(restored == state)
        #expect(restored.schedules[0].location != nil)
        #expect(restored.schedules[0].attendanceWindow != nil)
        // 비대면 일정은 위치·정책이 함께 비어 있어야 한다.
        #expect(restored.schedules[1].location == nil)
        #expect(restored.schedules[1].attendanceWindow == nil)
        #expect(restored.schedules[1].attendanceStatus == nil)
    }

    @Test("attendanceChanged 왕복 — 서버 원본 상태 문자열이 축약되지 않는다")
    func attendanceChangedPreservesServerStatus() throws {
        let result = makeResult(status: "EXCUSED")

        guard case .attendanceChanged(let restored) = try roundtrip(.attendanceChanged(result))
        else {
            Issue.record("attendanceChanged 로 디코딩되지 않음"); return
        }
        // 앱의 축약 enum 은 EXCUSED 를 present 로 합친다. 워치는 공결 전용 화면을 그려야 하므로
        // 이 문자열이 그대로 남아야 한다.
        #expect(restored.status == "EXCUSED")
    }

    @Test("다섯 종류가 섞여도 서로 오인되지 않는다")
    func kindsAreDistinguished() throws {
        let messages: [WatchMessage] = [
            .attendanceRequest(makeRequest()),
            .noticeRead(WatchNoticeRead(noticeId: "7", readAt: fixedDate)),
            .syncRequest,
            .sessionState(makeState()),
            .attendanceChanged(makeResult(status: "PRESENT"))
        ]

        for message in messages {
            #expect(kindTag(try roundtrip(message)) == kindTag(message))
        }
    }

    // MARK: - Reply

    @Test("WatchReply 네 종류가 왕복하고 서로 오인되지 않는다")
    func replyRoundtrip() throws {
        let replies: [WatchReply] = [
            .ack,
            .state(makeState()),
            .attendance(makeResult(status: "LATE")),
            .failure(WatchRemoteFailure(reason: .upstreamFailed, message: "500"))
        ]

        for reply in replies {
            let decoded = try WatchEnvelope.jsonDecoder.decode(
                WatchReply.self, from: WatchEnvelope.jsonEncoder.encode(reply)
            )
            #expect(decoded == reply)
        }

        let attendanceData = try WatchEnvelope.jsonEncoder.encode(
            WatchReply.attendance(makeResult(status: "PRESENT"))
        )
        if case .state = try WatchEnvelope.jsonDecoder.decode(
            WatchReply.self, from: attendanceData
        ) {
            Issue.record("attendance 응답이 state 로 오인됨")
        }
    }

    // MARK: - Schema

    @Test("모르는 버전은 조용히 오독하지 않고 던진다")
    func futureVersionIsRejected() throws {
        let data = Data(#"{"kind":"syncRequest","version":2}"#.utf8)

        do {
            _ = try WatchEnvelope.jsonDecoder.decode(WatchMessage.self, from: data)
            Issue.record("상한을 넘긴 버전이 통과함")
        } catch WatchConnectivityError.unsupportedSchemaVersion(let version) {
            #expect(version == 2)
        }
    }

    @Test("version 키가 없으면 v1 로 읽는다")
    func missingVersionFallsBackToV1() throws {
        let data = Data(#"{"kind":"syncRequest"}"#.utf8)

        guard case .syncRequest = try WatchEnvelope.jsonDecoder.decode(
            WatchMessage.self, from: data
        ) else {
            Issue.record("version 없는 봉투를 읽지 못함"); return
        }
    }

    @Test("모르는 kind 는 조용히 삼키지 않고 던진다")
    func unknownKindIsRejected() {
        let data = Data(#"{"kind":"futureThing","version":1}"#.utf8)

        #expect(throws: DecodingError.self) {
            try WatchEnvelope.jsonDecoder.decode(WatchMessage.self, from: data)
        }
    }

    @Test("응답 봉투도 모르는 kind 와 상한 넘긴 버전을 던진다")
    func replyRejectsUnknownKindAndFutureVersion() {
        // 응답은 요청과 반대 방향이라 계약이 따로 깨질 수 있다. 같은 규칙임을 여기서 고정한다.
        #expect(throws: DecodingError.self) {
            try WatchEnvelope.jsonDecoder.decode(
                WatchReply.self, from: Data(#"{"kind":"futureThing","version":1}"#.utf8)
            )
        }

        do {
            _ = try WatchEnvelope.jsonDecoder.decode(
                WatchReply.self, from: Data(#"{"kind":"ack","version":2}"#.utf8)
            )
            Issue.record("상한을 넘긴 응답 버전이 통과함")
        } catch WatchConnectivityError.unsupportedSchemaVersion(let version) {
            #expect(version == 2)
        } catch {
            Issue.record("예상과 다른 에러: \(error)")
        }
    }

    @Test("서버 정수 식별자는 JSON 에서도 문자열이다")
    func serverIdentifiersStayStrings() throws {
        let requestJSON = try #require(
            String(
                data: try WatchEnvelope.jsonEncoder.encode(
                    WatchMessage.attendanceRequest(makeRequest())
                ),
                encoding: .utf8
            )
        )
        let readJSON = try #require(
            String(
                data: try WatchEnvelope.jsonEncoder.encode(
                    WatchMessage.noticeRead(WatchNoticeRead(noticeId: "7", readAt: fixedDate))
                ),
                encoding: .utf8
            )
        )

        #expect(requestJSON.contains(#""scheduleId":"42""#))
        #expect(readJSON.contains(#""noticeId":"7""#))
    }

    // MARK: - Queue Age

    @Test("측정 후 180분까지는 큐에 남고 그 뒤엔 버린다")
    func expiryBoundary() {
        let request = makeRequest()

        #expect(!request.isExpired(now: fixedDate.addingTimeInterval(179 * 60)))
        #expect(!request.isExpired(now: fixedDate.addingTimeInterval(180 * 60)))
        #expect(request.isExpired(now: fixedDate.addingTimeInterval(181 * 60)))
    }
}
