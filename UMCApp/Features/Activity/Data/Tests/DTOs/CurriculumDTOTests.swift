//
//  CurriculumDTOTests.swift
//  ActivityDataTests
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import Testing
import ActivityDomain
import UMCFoundation
@testable import ActivityData

// MARK: - Fixed Timestamps
//
// 모든 시간 단언은 결정론을 위해 고정 epoch 를 사용한다.
//   week1: 2026-06-01T00:00:00Z(starts) ~ 2026-06-07T00:00:00Z(ends)
//   week2: 2026-06-08T00:00:00Z(starts) ~ 2026-06-14T00:00:00Z(ends)

private enum FixedTime {
    static let week1Start: TimeInterval = 1_780_272_000 // 2026-06-01T00:00:00Z
    static let week1End: TimeInterval = 1_780_790_400 // 2026-06-07T00:00:00Z
    static let week2Start: TimeInterval = 1_780_876_800 // 2026-06-08T00:00:00Z
    static let week2End: TimeInterval = 1_781_395_200 // 2026-06-14T00:00:00Z

    static let week1StartISO = "2026-06-01T00:00:00Z"
    static let week1EndISO = "2026-06-07T00:00:00Z"
    static let week2StartISO = "2026-06-08T00:00:00Z"
    static let week2EndISO = "2026-06-14T00:00:00Z"
}

// MARK: - Helpers

private func decodeCurriculum(_ json: String) throws -> CurriculumDTO {
    try JSONDecoder().decode(CurriculumDTO.self, from: Data(json.utf8))
}

private func makeWeekJSON(
    startsAt: String,
    endsAt: String,
    weeklyCurriculumId: String = "\"5001\"",
    weekNo: String = "1",
    title: String = "\"1주차: Swift 기초\"",
    isExtra: String = "false"
) -> String {
    """
    {
        "weeklyCurriculumId": \(weeklyCurriculumId),
        "weekNo": \(weekNo),
        "title": \(title),
        "startsAt": "\(startsAt)",
        "endsAt": "\(endsAt)",
        "isExtra": \(isExtra)
    }
    """
}

private func makeCurriculumJSON(
    curriculumId: String = "\"900\"",
    title: String = "\"iOS 커리큘럼\"",
    weeks: [String]
) -> String {
    """
    {
        "curriculumId": \(curriculumId),
        "title": \(title),
        "weeks": [\(weeks.joined(separator: ","))]
    }
    """
}

private func date(_ epoch: TimeInterval) -> Date { Date(timeIntervalSince1970: epoch) }

@Suite("CurriculumDTO — 디코딩/매핑")
struct CurriculumDTOTests {

    // MARK: - Decoding (happy path)

    @Test("커리큘럼 전체 JSON 의 필드와 주차 목록을 디코딩한다")
    func decodesFullCurriculumJSON() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: FixedTime.week1EndISO),
            makeWeekJSON(
                startsAt: FixedTime.week2StartISO,
                endsAt: FixedTime.week2EndISO,
                weeklyCurriculumId: "\"5002\"",
                weekNo: "2"
            )
        ])
        let dto = try decodeCurriculum(json)

        #expect(dto.curriculumId == "900")
        #expect(dto.title == "iOS 커리큘럼")
        #expect(dto.weeks.count == 2)
        #expect(dto.weeks.first?.weeklyCurriculumId == "5001")
        #expect(dto.weeks.first?.weekNo == 1)
    }

    @Test("curriculumId 가 JSON 숫자로 와도 String 으로 디코딩한다")
    func decodesCurriculumIdAsNumber() throws {
        let json = makeCurriculumJSON(curriculumId: "900", weeks: [])
        #expect(try decodeCurriculum(json).curriculumId == "900")
    }

    @Test("weekNo 가 숫자 String 으로 와도 Int 로 디코딩한다")
    func decodesWeekNoAsString() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: FixedTime.week1EndISO, weekNo: "\"3\"")
        ])
        #expect(try decodeCurriculum(json).weeks.first?.weekNo == 3)
    }

    @Test("isExtra 가 String/Int 등 다양한 형태로 와도 Bool 로 디코딩한다")
    func decodesIsExtraFlexibly() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: FixedTime.week1EndISO, isExtra: "\"true\"")
        ])
        #expect(try decodeCurriculum(json).weeks.first?.isExtra == true)
    }

    @Test("필드가 없으면 기본값으로 디코딩한다")
    func decodesWithDefaults() throws {
        let dto = try decodeCurriculum("{}")
        #expect(dto.curriculumId == "")
        #expect(dto.title == "")
        #expect(dto.weeks.isEmpty)
    }

    @Test("주차 JSON 에 필드가 없으면 기본값으로 디코딩한다")
    func decodesWeekWithDefaults() throws {
        let json = makeCurriculumJSON(weeks: ["{}"])
        let week = try #require(try decodeCurriculum(json).weeks.first)

        #expect(week.weeklyCurriculumId == "")
        #expect(week.weekNo == 0)
        #expect(week.title == "")
        #expect(week.startsAt == "")
        #expect(week.endsAt == "")
        #expect(week.isExtra == false)
    }

    @Test("custom encode 후 다시 디코딩하면 동일한 DTO 가 복원된다")
    func encodeRoundTrip() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: FixedTime.week1EndISO)
        ])
        let original = try decodeCurriculum(json)
        let restored = try JSONDecoder().decode(
            CurriculumDTO.self,
            from: JSONEncoder().encode(original)
        )
        #expect(restored == original)
    }

    // MARK: - toCurriculumProgress

    @Test("toCurriculumProgress — totalCount 는 주차 수, partType/partName 은 part 인자로부터 매핑된다")
    func progressMapsTotalsAndPart() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: FixedTime.week1EndISO),
            makeWeekJSON(
                startsAt: FixedTime.week2StartISO,
                endsAt: FixedTime.week2EndISO,
                weekNo: "2"
            )
        ])
        let progress = try decodeCurriculum(json)
            .toCurriculumProgress(part: "IOS", now: date(FixedTime.week1Start))

        #expect(progress.totalCount == 2)
        #expect(progress.partType == .front(type: .ios))
        #expect(progress.partName == "iOS PART CURRICULUM")
    }

    @Test("toCurriculumProgress — 알 수 없는 part 는 partType nil, partName 에 원본 문자열을 쓴다")
    func progressUnknownPartFallback() throws {
        let json = makeCurriculumJSON(weeks: [])
        let progress = try decodeCurriculum(json)
            .toCurriculumProgress(part: "QUANTUM", now: date(FixedTime.week1Start))

        #expect(progress.partType == nil)
        #expect(progress.partName == "QUANTUM PART CURRICULUM")
    }

    @Test("toCurriculumProgress — now 가 주차 end 보다 이전이면 완료로 세지 않는다")
    func progressNotCompletedBeforeEnd() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: FixedTime.week1EndISO)
        ])
        let progress = try decodeCurriculum(json)
            .toCurriculumProgress(part: "IOS", now: date(FixedTime.week1End - 1))
        #expect(progress.completedCount == 0)
    }

    @Test("toCurriculumProgress — now 가 주차 end 와 정확히 같으면 완료로 세지 않는다 (strict >)")
    func progressNotCompletedAtExactEnd() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: FixedTime.week1EndISO)
        ])
        let progress = try decodeCurriculum(json)
            .toCurriculumProgress(part: "IOS", now: date(FixedTime.week1End))
        #expect(progress.completedCount == 0)
    }

    @Test("toCurriculumProgress — now 가 주차 end 보다 이후면 완료로 센다")
    func progressCompletedAfterEnd() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: FixedTime.week1EndISO)
        ])
        let progress = try decodeCurriculum(json)
            .toCurriculumProgress(part: "IOS", now: date(FixedTime.week1End + 1))
        #expect(progress.completedCount == 1)
    }

    @Test("toCurriculumProgress — endsAt 파싱 불가 주차는 완료로 세지 않는다")
    func progressIgnoresUnparsableEnd() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: "invalid-date")
        ])
        let progress = try decodeCurriculum(json)
            .toCurriculumProgress(part: "IOS", now: date(FixedTime.week2End))
        #expect(progress.completedCount == 0)
    }

    @Test("toCurriculumProgress — 진행 중 주차가 있으면 그 제목을 curriculumTitle 로 쓴다")
    func progressUsesInProgressWeekTitle() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(
                startsAt: FixedTime.week1StartISO,
                endsAt: FixedTime.week1EndISO,
                title: "\"진행 중 주차\""
            )
        ])
        let progress = try decodeCurriculum(json)
            .toCurriculumProgress(part: "IOS", now: date(FixedTime.week1Start + 1))
        #expect(progress.curriculumTitle == "진행 중 주차")
    }

    @Test("toCurriculumProgress — 진행 중 주차가 없으면 커리큘럼 title 로 폴백한다")
    func progressFallsBackToCurriculumTitle() throws {
        let json = makeCurriculumJSON(title: "\"폴백 타이틀\"", weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: FixedTime.week1EndISO)
        ])
        let progress = try decodeCurriculum(json)
            .toCurriculumProgress(part: "IOS", now: date(FixedTime.week2End))
        #expect(progress.curriculumTitle == "폴백 타이틀")
    }

    // MARK: - toMissionCards

    @Test("toMissionCards — 주차를 week 오름차순으로 정렬해 카드로 변환한다")
    func missionCardsSortedByWeek() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(
                startsAt: FixedTime.week2StartISO,
                endsAt: FixedTime.week2EndISO,
                weekNo: "2"
            ),
            makeWeekJSON(
                startsAt: FixedTime.week1StartISO,
                endsAt: FixedTime.week1EndISO,
                weekNo: "1"
            )
        ])
        let cards = try decodeCurriculum(json)
            .toMissionCards(platform: "iOS", now: date(FixedTime.week1Start))

        #expect(cards.map(\.week) == [1, 2])
    }

    @Test("toMissionCards — platform/missionTitle/missionType/isExtra 가 매핑된다")
    func missionCardsMapFields() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(
                startsAt: FixedTime.week1StartISO,
                endsAt: FixedTime.week1EndISO,
                title: "\"1주차 미션\"",
                isExtra: "true"
            )
        ])
        let card = try #require(
            try decodeCurriculum(json)
                .toMissionCards(platform: "iOS", now: date(FixedTime.week1Start)).first
        )

        #expect(card.platform == "iOS")
        #expect(card.title == "1주차 미션")
        #expect(card.missionTitle == "1주차 미션")
        #expect(card.missionType == .link)
        #expect(card.isExtra == true)
    }

    @Test(
        "toMissionCards — now 의 위치에 따라 missionStatus 가 3개 영역으로 결정된다",
        arguments: [
            (FixedTime.week1Start - 1, MissionStatus.notStarted),
            (FixedTime.week1Start, MissionStatus.inProgress),
            (FixedTime.week1End, MissionStatus.inProgress),
            (FixedTime.week1End + 1, MissionStatus.completed)
        ]
    )
    func missionStatusAcrossTimeRegions(now: TimeInterval, expected: MissionStatus) throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: FixedTime.week1StartISO, endsAt: FixedTime.week1EndISO)
        ])
        let card = try #require(
            try decodeCurriculum(json)
                .toMissionCards(platform: "iOS", now: date(now)).first
        )
        #expect(card.status == expected)
    }

    @Test("toMissionCards — startsAt/endsAt 파싱 불가 주차는 notStarted 로 매핑된다")
    func missionStatusUnparsableDatesNotStarted() throws {
        let json = makeCurriculumJSON(weeks: [
            makeWeekJSON(startsAt: "bad", endsAt: "bad")
        ])
        let card = try #require(
            try decodeCurriculum(json)
                .toMissionCards(platform: "iOS", now: date(FixedTime.week1End)).first
        )
        #expect(card.status == .notStarted)
    }

    @Test("toMissionCards — 빈 주차 목록이면 빈 카드 배열을 반환한다")
    func missionCardsEmptyWhenNoWeeks() throws {
        let json = makeCurriculumJSON(weeks: [])
        let cards = try decodeCurriculum(json)
            .toMissionCards(platform: "iOS", now: date(FixedTime.week1Start))
        #expect(cards.isEmpty)
    }
}
