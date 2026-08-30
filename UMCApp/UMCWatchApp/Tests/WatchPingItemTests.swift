import Foundation
import Testing
import CoreWatchConnectivity
@testable import UMCWatchApp

@Suite("WatchPingItem — 목록 표시 모델")
struct WatchPingItemTests {

    // MARK: - Function

    private func notice(
        id: String,
        postedAt: Date,
        isMustRead: Bool = false,
        isAlert: Bool = false,
        isRead: Bool = false
    ) -> WatchNotice {
        WatchNotice(
            noticeId: id,
            title: "공지 \(id)",
            content: "본문 \(id)",
            writer: "운영진",
            postedAt: postedAt,
            isMustRead: isMustRead,
            isAlert: isAlert,
            isRead: isRead
        )
    }

    // MARK: - Test

    @Test("최신순으로 정렬한다 — 읽음 여부는 순서를 바꾸지 않는다")
    func sortsByPostedAtDescendingRegardlessOfReadState() {
        let base = Date(timeIntervalSince1970: 1_800_000_000)
        let notices = [
            notice(id: "1", postedAt: base, isRead: true),
            notice(id: "2", postedAt: base.addingTimeInterval(600)),
            notice(id: "3", postedAt: base.addingTimeInterval(-600)),
        ]

        let items = WatchPingItem.list(from: notices, readReceiptIDs: [])

        #expect(items.map(\.id) == ["2", "1", "3"])
    }

    @Test("워치에서 확인한 공지는 스냅샷이 미확인이어도 읽음으로 보인다")
    func readReceiptOverridesSnapshotReadState() {
        let notices = [notice(id: "10", postedAt: .now, isRead: false)]

        let items = WatchPingItem.list(from: notices, readReceiptIDs: ["10"])

        #expect(items[0].isRead)
    }

    @Test("확인하지 않은 공지는 스냅샷 값을 그대로 따른다")
    func keepsSnapshotReadStateWithoutReceipt() {
        let notices = [
            notice(id: "10", postedAt: .now, isRead: false),
            notice(id: "11", postedAt: .now.addingTimeInterval(-60), isRead: true),
        ]

        let items = WatchPingItem.list(from: notices, readReceiptIDs: [])

        #expect(items.map(\.isRead) == [false, true])
    }

    @Test("안읽음과 긴급은 서로 다른 축이라 한 행에서 동시에 켜진다")
    func unreadAndUrgentAreIndependentSignals() {
        let notices = [notice(id: "20", postedAt: .now, isAlert: true, isRead: false)]

        let item = WatchPingItem.list(from: notices, readReceiptIDs: [])[0]

        #expect(item.isUrgent)
        #expect(!item.isRead)
    }

    @Test("확인한 긴급 공지는 긴급 신호만 남는다")
    func urgentSurvivesReadReceipt() {
        let notices = [notice(id: "21", postedAt: .now, isAlert: true)]

        let item = WatchPingItem.list(from: notices, readReceiptIDs: ["21"])[0]

        #expect(item.isUrgent)
        #expect(item.isRead)
    }

    @Test("VoiceOver 라벨이 색·위치 신호를 모두 글자로 푼다")
    func accessibilityLabelSpellsOutEverySignal() {
        let notices = [
            notice(id: "30", postedAt: .now, isMustRead: true, isAlert: true)
        ]

        let label = WatchPingItem.list(from: notices, readReceiptIDs: [])[0].accessibilityLabel

        #expect(label.contains("미확인"))
        #expect(label.contains("긴급"))
        #expect(label.contains("필수 확인"))
        #expect(label.contains("공지 30"))
    }

    @Test("확인한 공지의 낭독은 '확인함'으로 시작한다")
    func accessibilityLabelReportsReadState() {
        let notices = [notice(id: "31", postedAt: .now)]

        let label = WatchPingItem.list(from: notices, readReceiptIDs: ["31"])[0].accessibilityLabel

        #expect(label.hasPrefix("확인함"))
    }
}
