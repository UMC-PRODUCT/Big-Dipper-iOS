//
//  ActivityStatRepositoryProtocol.swift
//  BusinessCardDomain
//
//  Created by One on 8/16/26.
//

import Foundation

/// 마이페이지 행 카운트 저장소 경계 (MP-F07~F09).
///
/// 서버 통합 카운트와 로컬 파생 카운트를 나눈다. 「나의 활동·프로젝트」 수만 로컬인 이유는
/// 그 값이 마이페이지 활동 목록과 **같은 배열**(`Profile.activityLogs()`)에서 나와야 하기
/// 때문이다 — 서버로 옮기면 목록과 숫자의 규칙이 갈린다 (#1222).
///
/// 실패는 「0개」가 아니라 「못 셌다」로 남긴다. 둘을 섞으면 사용자가 빈 목록을 사실로
/// 믿는다 (#1222).
public protocol ActivityStatRepositoryProtocol: Sendable {
    /// 서버 통합 카운트. 필드별 `nil` 이 「못 셌다」다.
    func fetchMemberStats() async throws -> MemberStats
    /// 로컬 집계(`Profile.activityLogs()` 항목 수) — 서버 정수가 아니라 Int.
    func fetchActivityCount() async throws -> Int
}
