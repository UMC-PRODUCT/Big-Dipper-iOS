//
//  HomeRepositoryProtocol.swift
//  AppProduct
//
//  Created by euijjang97 on 2/12/26.
//

import Foundation

/// Home 데이터 접근 Repository Protocol
protocol HomeRepositoryProtocol: Sendable {

    /// 내 프로필 조회 (기수 카드 + 역할 정보)
    /// - Returns: 기수 카드용 데이터 + 역할별 (challengerId, gisuId) 매핑
    func getMyProfile() async throws -> HomeProfileResult

    /// 기간 내 내 일정 조회 (V2)
    ///
    /// - Parameters:
    ///   - from: 조회 시작 시각 (UTC ISO8601 송신, 일반적으로 KST 월초 자정)
    ///   - to: 조회 종료 시각 (UTC ISO8601 송신, 일반적으로 KST 월말 23:59:59.999)
    ///   - isAttendanceRequired: 출석 필수 일정만 조회할지 여부
    /// - Returns: KST 자정 기준 날짜별로 그룹핑된 일정 딕셔너리
    func fetchMySchedules(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]]

    /// 일정 상세 조회
    /// - Parameter scheduleId: 일정 ID
    /// - Returns: 일정 상세 데이터
    func getScheduleDetail(
        scheduleId: Int
    ) async throws -> ScheduleDetailData

    /// 최근 공지 조회
    /// - Parameter query: 공지 목록 요청 파라미터
    /// - Returns: 최근 공지 데이터 목록
    func getRecentNotices(
        query: NoticeListRequestDTO
    ) async throws -> [RecentNoticeData]

    /// FCM 토큰 등록/갱신
    /// - Parameter fcmToken: Firebase Cloud Messaging 토큰
    func registerFCMToken(
        fcmToken: String
    ) async throws
}
