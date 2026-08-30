//
//  WatchEnvelopeTests.swift
//  CoreWatchConnectivityTests
//
//  Created by euijjang97 on 8/29/26.
//

import Foundation
import Testing
import WatchConnectivity
@testable import CoreWatchConnectivity

/// 봉투를 WCSession 딕셔너리에 싣는 계약.
///
/// 세 채널(`sendMessage`·`updateApplicationContext`·`transferUserInfo`)이 같은 코덱을 쓰는데,
/// 뒤의 둘은 plist 로 직렬화되는 딕셔너리만 받는다. 그 제약을 여기서 고정한다.
@Suite("WatchEnvelope — 딕셔너리 래핑")
struct WatchEnvelopeTests {

    // MARK: - Fixture

    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private func makeMessage() -> WatchMessage {
        .attendanceRequest(
            WatchAttendanceRequest(
                scheduleId: "42",
                latitude: 37.557_192,
                longitude: 127.045_5,
                locationVerified: true,
                measuredAt: fixedDate
            )
        )
    }

    // MARK: - Roundtrip

    @Test("딕셔너리 래핑·언래핑 왕복")
    func dictionaryRoundtrip() throws {
        let message = makeMessage()

        let decoded = try WatchEnvelope.decode(
            WatchMessage.self, from: try WatchEnvelope.encode(message)
        )

        #expect(decoded == message)
    }

    @Test("래핑 결과는 plist 호환이다 — 값이 Data 하나뿐이다")
    func wrappedDictionaryIsPropertyList() throws {
        let dictionary = try WatchEnvelope.encode(makeMessage())

        #expect(dictionary.count == 1)
        #expect(dictionary[WatchEnvelope.payloadKey] is Data)
        #expect(PropertyListSerialization.propertyList(dictionary, isValidFor: .binary))
    }

    // MARK: - Malformed

    @Test("키가 없는 딕셔너리는 malformedPayload")
    func missingKeyIsMalformed() {
        do {
            _ = try WatchEnvelope.decode(WatchMessage.self, from: [:])
            Issue.record("키 없는 딕셔너리가 통과함")
        } catch WatchConnectivityError.malformedPayload(let description) {
            #expect(!description.isEmpty)
        } catch {
            Issue.record("예상과 다른 에러: \(error)")
        }
    }

    @Test("값이 Data 가 아니면 malformedPayload")
    func nonDataValueIsMalformed() {
        do {
            _ = try WatchEnvelope.decode(
                WatchMessage.self, from: [WatchEnvelope.payloadKey: "not data"]
            )
            Issue.record("Data 가 아닌 값이 통과함")
        } catch WatchConnectivityError.malformedPayload(let description) {
            #expect(!description.isEmpty)
        } catch {
            Issue.record("예상과 다른 에러: \(error)")
        }
    }

    @Test("손상된 JSON 은 malformedPayload")
    func corruptedJSONIsMalformed() {
        let payload: [String: Any] = [WatchEnvelope.payloadKey: Data("{not json".utf8)]

        do {
            _ = try WatchEnvelope.decode(WatchMessage.self, from: payload)
            Issue.record("손상된 JSON 이 통과함")
        } catch WatchConnectivityError.malformedPayload(let description) {
            #expect(!description.isEmpty)
        } catch {
            Issue.record("예상과 다른 에러: \(error)")
        }
    }

    @Test("딕셔너리 경로에서도 버전 상한 신호가 손상으로 뭉개지지 않는다")
    func futureVersionSurvivesDictionaryPath() {
        // 실제 수신 경로는 딕셔너리다. 여기서 malformedPayload 로 덮이면 상대는 「업데이트
        // 필요」 대신 「손상」이라는 답을 받고 원인을 찾지 못한다.
        let payload: [String: Any] = [
            WatchEnvelope.payloadKey: Data(#"{"kind":"syncRequest","version":2}"#.utf8)
        ]

        do {
            _ = try WatchEnvelope.decode(WatchMessage.self, from: payload)
            Issue.record("상한을 넘긴 버전이 통과함")
        } catch WatchConnectivityError.unsupportedSchemaVersion(let version) {
            #expect(version == 2)
        } catch {
            Issue.record("예상과 다른 에러: \(error)")
        }
    }

    // MARK: - Fallback

    @Test("encodeFallback 은 어떤 응답에도 빈 결과를 내지 않는다")
    func encodeFallbackAlwaysProducesPayload() {
        let replies: [WatchReply] = [
            .ack,
            .state(
                WatchSessionState(
                    isSignedIn: false, schedules: [], notices: [], generatedAt: fixedDate
                )
            ),
            .attendance(
                WatchAttendanceResult(
                    scheduleId: "42", status: "PRESENT", decidedAt: nil, reason: nil
                )
            ),
            .failure(WatchRemoteFailure(reason: .malformedPayload))
        ]

        for reply in replies {
            let encoded = WatchEnvelope.encodeFallback(reply)
            #expect(encoded[WatchEnvelope.payloadKey] is Data)
        }
    }

    // MARK: - Error Classification

    @Test("WCError 코드는 처리 방법이 다른 도메인 에러로 갈린다")
    func wcErrorCodesAreClassified() {
        func classify(_ code: WCError.Code) -> WatchConnectivityError {
            WatchConnectivityError.from(
                NSError(domain: WCError.errorDomain, code: code.rawValue)
            )
        }

        guard case .notReachable = classify(.notReachable) else {
            Issue.record("7007 이 notReachable 로 분류되지 않음"); return
        }
        guard case .payloadTooLarge = classify(.payloadTooLarge) else {
            Issue.record("7009 가 payloadTooLarge 로 분류되지 않음"); return
        }
        guard case .replyTimedOut = classify(.messageReplyTimedOut) else {
            Issue.record("7012 가 replyTimedOut 으로 분류되지 않음"); return
        }
        guard case .transportFailure = classify(.genericError) else {
            Issue.record("분류 대상이 아닌 코드가 transportFailure 로 떨어지지 않음"); return
        }
    }

    @Test("WCError 가 아닌 에러는 transportFailure 로 감싼다")
    func foreignErrorFallsBackToTransportFailure() {
        let error = WatchConnectivityError.from(
            NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        )

        guard case .transportFailure = error else {
            Issue.record("다른 도메인의 에러가 transportFailure 로 감싸이지 않음"); return
        }
    }
}
