import Foundation

/// 홈 일정 캘린더 데이터 접근 계층 인터페이스.
///
/// 조회 전용이다. 일정 생성/수정/삭제·출석 관련 액션은 이 슬라이스(#914)의 범위 밖으로,
/// 등록/출석 기능 이식 시 별도 Repository로 추가한다.
public protocol ScheduleRepositoryProtocol {

    /// 기간 내 내 일정을 조회해 KST 자정 기준 날짜별로 그룹핑한다.
    ///
    /// - Parameters:
    ///   - from: 조회 시작 시각 (UTC ISO8601 송신, 통상 KST 월초 자정)
    ///   - to: 조회 종료 시각 (UTC ISO8601 송신, 통상 KST 월말 23:59:59.999)
    ///   - isAttendanceRequired: 출석 필수 일정만 조회할지 여부
    func fetchMySchedules(
        from: Date,
        to: Date,
        isAttendanceRequired: Bool
    ) async throws -> [Date: [ScheduleDetailData]]
}
