//
//  ActivityStatRepositoryProtocol.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 마이페이지 행 카운트 저장소 경계 (MP-F07~F09).
///
/// 통합 stat API가 없어 기존 소스를 조합한다. 소스별 개별 메서드로 쪼갠 이유는
/// 개별 실패를 UseCase가 "0" 폴백으로 흡수해야 하기 때문(단일 throwing 메서드로는
/// 소스별 폴백이 불가). 받은 명함 수는 `ReceivedCardRepositoryProtocol.count()` 담당.
///
/// 반환 타입이 갈리는 이유: **스크랩만 서버 응답 정수(totalElements) 원본이라 String,
/// 나머지 둘은 로컬 집계라 Int** (절대규칙 #2).
public protocol ActivityStatRepositoryProtocol: Sendable {
    /// 로컬 집계(응답 배열 항목 수) — 서버 정수가 아니라 Int.
    func fetchStudyCount() async throws -> Int
    /// 서버 응답 정수(`totalElements`) 원본 그대로. Repository가 Int로 변환하면 규칙
    /// 위반이고 `?? 0`이 비정상 값을 조용히 삼킨다.
    func fetchBookmarkCount() async throws -> String
    /// 로컬 집계(admin 제외 challengerRecords 수) — 서버 정수가 아니라 Int.
    func fetchActivityCount() async throws -> Int
}
