import Testing
@testable import HomeDomain

@Suite("NoticeHistoryData — icon rawValue 브리징 검증")
struct NoticeHistoryDataTests {

    @Test("init에 넘긴 타입이 iconRaw로 저장되고 icon으로 그대로 복원된다")
    func iconRoundTripsThroughRawValue() {
        for expected in [NoticeAlarmType.success, .info, .warning, .error] {
            let notice = NoticeHistoryData(
                title: "제목",
                content: "내용",
                icon: expected,
                createdAt: .init(timeIntervalSince1970: 0)
            )

            #expect(notice.iconRaw == expected.rawValue)
            #expect(notice.icon == expected)
        }
    }

    @Test("icon setter가 iconRaw를 갱신한다")
    func iconSetterUpdatesRawValue() {
        let notice = NoticeHistoryData(
            title: "제목",
            content: "내용",
            icon: .info,
            createdAt: .init(timeIntervalSince1970: 0)
        )

        notice.icon = .error

        #expect(notice.iconRaw == NoticeAlarmType.error.rawValue)
        #expect(notice.icon == .error)
    }

    @Test("알 수 없는 iconRaw는 info로 fallback한다")
    func unknownRawValueFallsBackToInfo() {
        let notice = NoticeHistoryData(
            title: "제목",
            content: "내용",
            icon: .warning,
            createdAt: .init(timeIntervalSince1970: 0)
        )

        notice.iconRaw = "존재하지_않는_타입"

        #expect(notice.icon == .info)
    }
}
