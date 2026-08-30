//
//  WatchEnvelope.swift
//  CoreWatchConnectivity
//
//  Created by euijjang97 on 8/29/26.
//

import Foundation

// MARK: - WatchSchema

/// 봉투 스키마 버전. ``WatchMessage`` 와 ``WatchReply`` 가 공유한다.
///
/// 상한을 검증하는 이유는 워치와 iPhone 이 서로 다른 시점에 업데이트되기 때문이다.
/// 상한이 없으면 미래의 v2 를 v1 로 읽고 **틀린 값을 조용히 받아들인다.**
public enum WatchSchema {
    public static let currentVersion = 1
}

// MARK: - WatchEnvelope

/// 봉투 ↔ WCSession 딕셔너리 코덱.
///
/// `sendMessage` · `updateApplicationContext` · `transferUserInfo` 세 채널이 **하나의 코덱을
/// 공유**하도록 JSON 을 단일 키에 통째로 싣는다. 필드를 딕셔너리에 펼치면 plist 타입 제약
/// (옵셔널·중첩·enum 불가)을 페이로드마다 손으로 우회해야 한다.
///
/// `WatchConnectivity` 를 import 하지 않는다 — `WCSession` 을 활성화할 수 없는 유닛 테스트
/// 환경에서도 계약 전체를 검증할 수 있어야 한다.
public enum WatchEnvelope {

    // MARK: - Property

    /// JSON 을 싣는 단일 키. `Data` 는 plist 원시 타입이라 세 채널 모두 그대로 통과한다.
    static let payloadKey = "p"

    static let jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let jsonDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    // MARK: - Function

    public static func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
        do {
            return [payloadKey: try jsonEncoder.encode(value)]
        } catch {
            throw WatchConnectivityError.malformedPayload("봉투 인코딩 실패: \(error)")
        }
    }

    public static func decode<T: Decodable>(
        _ type: T.Type,
        from dictionary: [String: Any]
    ) throws -> T {
        guard let data = dictionary[payloadKey] as? Data else {
            throw WatchConnectivityError.malformedPayload("봉투 키 '\(payloadKey)' 없음")
        }
        do {
            return try jsonDecoder.decode(type, from: data)
        } catch let error as WatchConnectivityError {
            // 버전 상한 위반은 손상과 다른 신호다 — 뭉개면 호출자가 업데이트 안내를 못 한다.
            throw error
        } catch {
            throw WatchConnectivityError.malformedPayload("봉투 디코딩 실패: \(error)")
        }
    }

    /// **절대 throw 하지 않는** 응답 인코더.
    ///
    /// `replyHandler` 는 어떤 경우에도 정확히 한 번 호출돼야 한다. 인코딩이 실패했다고 호출을
    /// 건너뛰면 송신자는 원인 없이 타임아웃(7012)만 본다. 그래서 실패 시 빈 딕셔너리를 보내고
    /// 송신자가 봉투 오류로 처리하게 둔다.
    public static func encodeFallback(_ reply: WatchReply) -> [String: Any] {
        (try? encode(reply)) ?? [:]
    }
}
