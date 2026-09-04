//
//  ReceivedCardRepositoryProtocol.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 명함첩 저장소 경계 (MP-F05).
///
/// 로컬(SwiftData)이 캐시, 서버 집합이 정본이다. 서버 명함 API 가 아직 없어서 릴리스
/// 구성에서는 ``sync()`` 가 no-op 이고 동작이 완전한 로컬 전용과 같다.
///
/// 모든 메서드는 **현재 로그인 계정 범위**로 동작한다. 소유자를 파라미터로 받지 않는 것은
/// 의도다 — 받게 하면 호출부가 언젠가 빼먹고, 그 순간 계정 격리가 뚫린다(#1217).
public protocol ReceivedCardRepositoryProtocol: Sendable {
    /// 교환 시각 내림차순 전체 조회.
    func fetchAll() async throws -> [ReceivedCard]
    func search(query: String) async throws -> [ReceivedCard]
    /// 정체성(memberId, 없으면 명함 내용) 기준 upsert — 재교환 시 최신 명함으로 갱신.
    func save(_ card: ReceivedCard) async throws
    /// 목록에서 고른 명함의 cardID. 같은 정체성의 레코드가 여러 벌이면 함께 지운다.
    func delete(id: String) async throws
    /// 현재 계정의 명함 전량 삭제 — 회원 탈퇴 전용.
    func deleteAll() async throws
    /// 로컬 집계라 Int (핵심규칙 #2의 서버 정수 대상 아님).
    func count() async throws -> Int

    /// 서버 집합으로 로컬 캐시를 재조정한다. 원격이 없으면 아무 일도 하지 않는다.
    ///
    /// 조회(``fetchAll()``·``search(query:)``)에 동기화를 묶지 않는 이유는 검색이 타이핑
    /// 디바운스마다 호출되기 때문이다 — 묶으면 글자마다 전량 동기화가 나간다.
    /// 별도 메서드인 이유는 「동기화 실패」와 「목록 조회 실패」의 처리가 다르기 때문이다:
    /// 동기화가 실패해도 캐시로 목록은 떠야 한다.
    func sync() async throws
}
