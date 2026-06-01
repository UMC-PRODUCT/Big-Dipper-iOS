//
//  SessionInfoTests.swift
//  ActivityDomainTests
//
//  Created by jaewon Lee on 5/7/26.
//

import Foundation
import Testing
import UMCFoundation
@testable import ActivityDomain

@Suite("SessionInfo — 값 동등성 + 기본값 (도메인 규칙)")
struct SessionInfoTests {

    // MARK: - Helper

    private func makeInfo(
        sessionId: String = "S-1",
        category: ScheduleIconCategory = .general,
        title: String = "1주차 OT",
        week: Int = 1,
        isAllDay: Bool = false
    ) -> SessionInfo {
        SessionInfo(
            sessionId: SessionID(value: sessionId),
            category: category,
            iconName: "calendar.badge",
            title: title,
            week: week,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            location: Coordinate(latitude: 37.5, longitude: 127.0),
            isAllDay: isAllDay
        )
    }

    // MARK: - Default Values

    @Test("category 기본값은 .general 이다")
    func defaultCategoryIsGeneral() {
        let info = SessionInfo(
            sessionId: SessionID(value: "S-1"),
            iconName: "calendar.badge",
            title: "기본",
            week: 1,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            location: Coordinate(latitude: 0, longitude: 0)
        )

        #expect(info.category == .general)
    }

    @Test("isAllDay 기본값은 false 이다")
    func defaultIsAllDayIsFalse() {
        let info = SessionInfo(
            sessionId: SessionID(value: "S-1"),
            iconName: "calendar.badge",
            title: "기본",
            week: 1,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            location: Coordinate(latitude: 0, longitude: 0)
        )

        #expect(info.isAllDay == false)
    }

    // MARK: - Equatable

    @Test("동일한 모든 프로퍼티(같은 id 포함)면 Equatable 비교가 같다")
    func equalWhenAllPropertiesMatch() {
        let sharedID = UUID()
        let lhs = SessionInfo(
            id: sharedID,
            sessionId: SessionID(value: "S-1"),
            iconName: "calendar.badge",
            title: "OT",
            week: 1,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            location: Coordinate(latitude: 1, longitude: 2)
        )
        let rhs = SessionInfo(
            id: sharedID,
            sessionId: SessionID(value: "S-1"),
            iconName: "calendar.badge",
            title: "OT",
            week: 1,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            location: Coordinate(latitude: 1, longitude: 2)
        )

        #expect(lhs == rhs)
    }

    @Test("UUID(id)가 다르면 Equatable 비교가 다르다")
    func notEqualWhenIDDiffers() {
        let lhs = makeInfo()
        let rhs = makeInfo()  // 새 UUID 생성

        #expect(lhs != rhs)
    }

    // MARK: - Category

    @Test("카테고리가 다르면 Equatable 비교가 다르다")
    func notEqualWhenCategoryDiffers() {
        let sharedID = UUID()
        let general = SessionInfo(
            id: sharedID,
            sessionId: SessionID(value: "S-1"),
            category: .general,
            iconName: "calendar.badge",
            title: "OT",
            week: 1,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            location: Coordinate(latitude: 0, longitude: 0)
        )
        let study = SessionInfo(
            id: sharedID,
            sessionId: SessionID(value: "S-1"),
            category: .study,
            iconName: "calendar.badge",
            title: "OT",
            week: 1,
            startTime: Date(timeIntervalSince1970: 0),
            endTime: Date(timeIntervalSince1970: 3600),
            location: Coordinate(latitude: 0, longitude: 0)
        )

        #expect(general != study)
    }
}
