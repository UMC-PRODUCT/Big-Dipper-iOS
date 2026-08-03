//
//  MyAttendanceItemModelTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

@Suite("MyAttendanceItemModel — 변환/표시 (도메인 규칙)")
struct MyAttendanceItemModelTests {

    // MARK: - Helper

    private func makeHistoryItem(
        status: AttendanceStatus = .present,
        startTime: String = "09:00",
        endTime: String = "11:00"
    ) -> AttendanceHistoryItem {
        AttendanceHistoryItem(
            attendanceId: 1,
            scheduleId: 10,
            scheduleName: "1주차 OT",
            tags: ["OT"],
            scheduledDate: "2026-05-07",
            startTime: startTime,
            endTime: endTime,
            status: status,
            statusDisplay: "출석"
        )
    }

    /// 2026-05-07 (목) KST 의 지정 시각. 기기 타임존과 무관하게 같은 절대 시각을 만든다.
    private func makeKSTDate(hour: Int, minute: Int = 0) -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 7
        components.hour = hour
        components.minute = minute

        guard let date = Calendar.kstGregorian.date(from: components) else {
            Issue.record("Failed to construct KST test date")
            return Date(timeIntervalSince1970: 0)
        }
        return date
    }

    private func makeSessionInfo() -> SessionInfo {
        SessionInfo(
            sessionId: SessionID(value: "S-1"),
            iconName: "calendar.badge",
            title: "1주차 OT",
            week: 1,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            location: Coordinate(latitude: 0, longitude: 0)
        )
    }

    /// 상태만 의미가 있는 출석 기록. 세션을 `beforeAttendance` 밖으로 꺼내는 용도라
    /// 나머지 필드는 변환 결과에 영향을 주지 않는 고정값이다.
    private func makeAttendance(
        status: AttendanceStatus = .present
    ) -> Attendance {
        Attendance(
            sessionId: SessionID(value: "S-1"),
            userId: UserID(value: "U-1"),
            type: .gps,
            status: status
        )
    }

    // MARK: - Computed Property

    @Test("weekText 는 '{week}주차' 형태이다")
    func weekTextFormat() {
        let model = MyAttendanceItemModel(
            week: 3,
            title: "Test",
            startTime: Date(),
            endTime: Date(),
            status: .present
        )

        #expect(model.weekText == "3주차")
    }

    @Test("timeRange 는 기기 타임존과 무관하게 KST 기준 'HH:mm - HH:mm' 이다")
    func timeRangeFormat() {
        let model = MyAttendanceItemModel(
            week: 1,
            title: "Test",
            startTime: makeKSTDate(hour: 14),
            endTime: makeKSTDate(hour: 16),
            status: .present
        )

        #expect(model.timeRange == "14:00 - 16:00")
    }

    @Test("dateText 는 KST 기준 'M월 d일 (E)' 형태이다")
    func dateTextFormat() {
        // 2026-05-07 은 목요일 (KST)
        let model = MyAttendanceItemModel(
            week: 1,
            title: "Test",
            startTime: makeKSTDate(hour: 14),
            endTime: makeKSTDate(hour: 16),
            status: .present
        )

        #expect(model.dateText == "5월 7일 (목)")
    }

    // MARK: - Init from AttendanceHistoryItem

    @Test("AttendanceHistoryItem(present) 변환 시 status 는 present")
    func initFromHistoryItemPresent() {
        let item = makeHistoryItem(status: .present)

        let model = MyAttendanceItemModel(from: item)

        #expect(model?.status == .present)
        #expect(model?.title == "1주차 OT")
        #expect(model?.week == 0)
    }

    @Test("AttendanceHistoryItem(beforeAttendance) 변환은 nil 반환")
    func initFromHistoryItemBeforeAttendanceReturnsNil() {
        let item = makeHistoryItem(status: .beforeAttendance)

        let model = MyAttendanceItemModel(from: item)

        #expect(model == nil)
    }

    @Test(
        "변환 시 변환 가능한 상태 enum 매핑 검증",
        arguments: [
            (AttendanceStatus.present, MyAttendanceItemStatus.present),
            (.late, .late),
            (.absent, .absent),
            (.pendingApproval, .pendingApproval)
        ]
    )
    func statusMappingFromHistory(
        legacy: AttendanceStatus,
        expected: MyAttendanceItemStatus
    ) {
        let item = makeHistoryItem(status: legacy)

        let model = MyAttendanceItemModel(from: item)

        #expect(model?.status == expected)
    }

    // MARK: - Init from Session

    @Test("Session(loaded(present)) 변환 시 status 는 present")
    @MainActor
    func initFromSessionPresent() {
        let session = Session(info: makeSessionInfo(), initialAttendance: makeAttendance())

        let model = MyAttendanceItemModel(from: session, category: .study)

        #expect(model?.status == .present)
        #expect(model?.category == .study)
        #expect(model?.title == "1주차 OT")
    }

    @Test("Session(idle) 변환은 nil 반환 (beforeAttendance 매핑)")
    @MainActor
    func initFromSessionIdleReturnsNil() {
        let session = Session(info: makeSessionInfo())

        let model = MyAttendanceItemModel(from: session)

        #expect(model == nil)
    }

    @Test("Session 변환 시 주입한 출석 정책이 그대로 실린다")
    @MainActor
    func initFromSessionCarriesAttendancePolicy() {
        let policy = ScheduleAttendancePolicy(
            checkInStartAt: makeKSTDate(hour: 13, minute: 50),
            onTimeEndAt: makeKSTDate(hour: 14, minute: 10),
            lateEndAt: makeKSTDate(hour: 15)
        )
        let session = Session(info: makeSessionInfo(), initialAttendance: makeAttendance())

        let model = MyAttendanceItemModel(from: session, attendancePolicy: policy)

        #expect(model?.attendancePolicy == policy)
    }

    /// 회귀 박제 — 두 변환 경로 **모두** 장소/비대면 정보를 싣지 않는다는 정의부 `- Note:` 를
    /// 고정한다. Schedule 모듈이 해당 페이로드를 들여올 때 이 테스트가 함께 바뀌어야 한다.
    @Test("Session 변환은 장소·비대면 정보를 싣지 않는다 (Schedule 모듈 대기)")
    @MainActor
    func initFromSessionHasNoLocationPayload() {
        let session = Session(info: makeSessionInfo(), initialAttendance: makeAttendance())

        let model = MyAttendanceItemModel(from: session)

        #expect(model?.locationName == nil)
        #expect(model?.isOnline == false)
    }

    @Test("AttendanceHistoryItem 변환도 장소·비대면 정보를 싣지 않는다 (형제 대칭)")
    func initFromHistoryItemHasNoLocationPayload() {
        let model = MyAttendanceItemModel(from: makeHistoryItem())

        #expect(model?.locationName == nil)
        #expect(model?.isOnline == false)
        #expect(model?.attendancePolicy == nil)
    }

    // MARK: - parseTimeString

    @Test("HH:mm 포맷 문자열은 오늘 날짜의 해당 시각으로 파싱된다")
    func parseTimeStringHHmm() {
        let date = MyAttendanceItemModel.parseTimeString("14:30")

        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        #expect(components.hour == 14)
        #expect(components.minute == 30)
    }

    @Test("ISO 8601 datetime 문자열은 해당 절대 시각으로 파싱된다")
    func parseTimeStringISO8601() {
        let iso = "2026-05-07T05:30:00Z"

        let date = MyAttendanceItemModel.parseTimeString(iso)

        let expected = ServerDateTimeConverter.parseUTCDateTime(iso)
        #expect(date == expected)
    }
}
