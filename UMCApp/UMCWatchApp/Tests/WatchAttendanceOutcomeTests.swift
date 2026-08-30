import Testing
@testable import UMCWatchApp

@Suite("WatchAttendanceOutcome — 푸시 status 매핑")
struct WatchAttendanceOutcomeTests {

    // MARK: - Test

    @Test(
        "확정 상태 4종은 그대로 매핑된다",
        arguments: [
            ("PRESENT", WatchAttendanceOutcome.present),
            ("LATE", .late),
            ("EXCUSED", .excused),
            ("ABSENT", .absent),
        ]
    )
    func mapsConfirmedStatuses(_ serverStatus: String, _ expected: WatchAttendanceOutcome) {
        #expect(WatchAttendanceOutcome(serverStatus: serverStatus) == expected)
    }

    @Test(
        "_PENDING 변형과 미지 문자열은 승인 대기로 흡수한다",
        arguments: ["PRESENT_PENDING", "LATE_PENDING", "EXCUSED_PENDING", "PENDING", "", "??"]
    )
    func absorbsPendingAndUnknownStatuses(_ serverStatus: String) {
        #expect(WatchAttendanceOutcome(serverStatus: serverStatus) == .pending)
    }

    /// 회귀 가드 — `ScheduleAttendanceStatus` 는 `"EXCUSED"` 를 `.present` 로 접는다.
    /// 워치에서 그 접힘이 되살아나면 공결에 초록(출석 확정)이 붙는다.
    @Test("EXCUSED 는 출석 확정으로 접히지 않는다")
    func doesNotFoldExcusedIntoPresent() {
        let outcome = WatchAttendanceOutcome(serverStatus: "EXCUSED")

        #expect(outcome == .excused)
        #expect(outcome != .present)
        #expect(outcome.title == "공결 인정")
        #expect(outcome.status == .pending)
        #expect(outcome.status != .success)
    }

    @Test("공결 심볼은 대기와 실루엣이 다르고 링이 없다")
    func excusedIsNeutralSolidWithDistinctSymbol() {
        let excused = WatchAttendanceOutcome.excused
        let pending = WatchAttendanceOutcome.pending

        #expect(excused.symbolName == "checkmark.seal")
        #expect(excused.symbolName != pending.symbolName)
        #expect(excused.ringTint == excused.symbolTint)
        #expect(pending.ringTint != pending.symbolTint)
    }

    @Test("결석만 위험 표면이고 출석 확정만 Hero 다")
    func cardStyleSeparatesOutcomes() {
        #expect(WatchAttendanceOutcome.present.cardStyle == .hero)
        #expect(WatchAttendanceOutcome.absent.cardStyle == .danger)
        #expect(WatchAttendanceOutcome.late.cardStyle == .standard)
        #expect(WatchAttendanceOutcome.excused.cardStyle == .standard)
        #expect(WatchAttendanceOutcome.pending.cardStyle == .standard)
    }
}
