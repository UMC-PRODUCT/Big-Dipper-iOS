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

    @Test("timeRange 는 'HH:mm - HH:mm' 형태이다")
    func timeRangeFormat() {
        // 시스템 타임존을 고려하여 컴포넌트 기반으로 Date 생성
        var startComponents = DateComponents()
        startComponents.year = 2026
        startComponents.month = 5
        startComponents.day = 7
        startComponents.hour = 14
        startComponents.minute = 0

        var endComponents = startComponents
        endComponents.hour = 16

        guard let start = Calendar.current.date(from: startComponents),
              let end = Calendar.current.date(from: endComponents) else {
            Issue.record("Failed to construct test dates")
            return
        }

        let model = MyAttendanceItemModel(
            week: 1,
            title: "Test",
            startTime: start,
            endTime: end,
            status: .present
        )

        #expect(model.timeRange == "14:00 - 16:00")
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
        let attendance = Attendance(
            sessionId: SessionID(value: "S-1"),
            userId: UserID(value: "U-1"),
            type: .gps,
            status: .present
        )
        let session = Session(info: makeSessionInfo(), initialAttendance: attendance)

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
