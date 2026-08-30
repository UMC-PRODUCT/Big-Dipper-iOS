import Testing
import UMCFoundation
@testable import UMCWatchApp

@MainActor
@Suite("WatchAttendanceResultViewModel — 결과 문구")
struct WatchAttendanceResultViewModelTests {

    // MARK: - Test

    @Test("누적 출석은 출석 확정에서만 나온다", arguments: WatchAttendanceOutcome.allCases)
    func showsCumulativeOnlyForPresent(_ outcome: WatchAttendanceOutcome) {
        let viewModel = Self.viewModel(outcome: .loaded(outcome), cumulativePresentCount: "7")

        #expect((viewModel.cumulativeText == "누적 출석 7회") == (outcome == .present))
    }

    @Test(
        "숫자가 아니거나 0 이하인 누적값은 감춘다",
        arguments: ["", "abc", "-1", "0", "7회"]
    )
    func hidesInvalidCumulativeCount(_ rawValue: String) {
        let viewModel = Self.viewModel(
            outcome: .loaded(.present),
            cumulativePresentCount: rawValue
        )

        #expect(viewModel.cumulativeText == nil)
    }

    @Test("결과를 받기 전에는 누적 출석을 띄우지 않는다")
    func hidesCumulativeBeforeOutcomeArrives() {
        let viewModel = Self.viewModel(outcome: .loading, cumulativePresentCount: "7")

        #expect(viewModel.cumulativeText == nil)
        #expect(viewModel.detailText == "운영진 승인을 기다리는 중입니다")
    }

    @Test("결과별 보조 문구가 서로 다르다")
    func detailTextDiffersByOutcome() {
        let details = WatchAttendanceOutcome.allCases.map {
            Self.viewModel(outcome: .loaded($0)).detailText
        }

        #expect(Set(details).count == WatchAttendanceOutcome.allCases.count)
        #expect(Self.viewModel(outcome: .loaded(.excused)).detailText == "공결로 인정되었습니다")
        #expect(
            Self.viewModel(outcome: .loaded(.late)).detailText
                == "정시 출석 창을 넘겨 지각으로 기록되었습니다"
        )
        #expect(
            Self.viewModel(outcome: .loaded(.absent)).detailText
                == "iPhone 에서 결석 사유를 제출할 수 있습니다"
        )
    }

    @Test("공결 사유는 주입될 때만 노출한다")
    func exposesExcuseReasonOnlyWhenInjected() {
        #expect(Self.viewModel(outcome: .loaded(.excused)).excuseReason == nil)
        #expect(
            Self.viewModel(outcome: .loaded(.excused), excuseReason: "학교 공식 행사")
                .excuseReason == "학교 공식 행사"
        )
    }

    // MARK: - Function

    private static func viewModel(
        outcome: Loadable<WatchAttendanceOutcome>,
        cumulativePresentCount: String = "0",
        excuseReason: String? = nil
    ) -> WatchAttendanceResultViewModel {
        WatchAttendanceResultViewModel(
            schedule: .watchSample(),
            outcome: outcome,
            cumulativePresentCount: cumulativePresentCount,
            excuseReason: excuseReason
        )
    }
}
