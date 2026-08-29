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
/// **한 소스가 실패해도 나머지 숫자는 보여야** 하기 때문(단일 throwing 메서드로는
/// 소스별 구분이 불가). 받은 명함 수는 `ReceivedCardRepositoryProtocol.count()` 담당.
///
/// 실패는 그대로 throw 한다 — "0"으로 눌러 담지 않는다. 「못 세었다」와 「0개다」를
/// 섞으면 사용자가 빈 목록을 사실로 믿는다 (#1222).
public protocol ActivityStatRepositoryProtocol: Sendable {
    /// 표시용 스터디 수. 커서 응답에 총개수가 없어 한 페이지 항목을 세므로, 다음 페이지가
    /// 있으면 잘렸다는 뜻으로 `"50+"` 처럼 `+`를 붙여 돌려준다.
    func fetchStudyCount() async throws -> String
    /// 서버 응답 정수(`totalElements`) 원본 그대로. Repository가 Int로 변환하면 규칙
    /// 위반이고 `?? 0`이 비정상 값을 조용히 삼킨다.
    func fetchBookmarkCount() async throws -> String
    /// 로컬 집계(`Profile.activityLogs()` 항목 수) — 서버 정수가 아니라 Int.
    func fetchActivityCount() async throws -> Int
}
