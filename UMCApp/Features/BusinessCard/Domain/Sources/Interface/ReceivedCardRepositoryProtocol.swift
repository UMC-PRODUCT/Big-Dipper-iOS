//
//  ReceivedCardRepositoryProtocol.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 명함첩 저장소 경계 (MP-F05).
///
/// 로컬(SwiftData) 전용 — 서버 명함 API 부재 확정(2026-08-15 서버 레포 전수 조사).
/// 서버가 생기면 구현체만 교체한다.
public protocol ReceivedCardRepositoryProtocol: Sendable {
    /// 교환 시각 내림차순 전체 조회.
    func fetchAll() async throws -> [ReceivedCard]
    func search(query: String) async throws -> [ReceivedCard]
    /// memberId(1차)·cardID(부차) 기준 upsert — 재교환 시 최신 명함으로 갱신.
    func save(_ card: ReceivedCard) async throws
    func delete(id: String) async throws
    /// 로컬 집계라 Int (절대규칙 #2의 서버 정수 대상 아님).
    func count() async throws -> Int
}
