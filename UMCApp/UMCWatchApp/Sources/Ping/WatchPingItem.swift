import Foundation
import CoreWatchConnectivity

// MARK: - WatchPingItem

/// The Ping 목록 한 행의 표시 모델.
///
/// `WatchNotice` 를 뷰에 그대로 넘기지 않는 이유는 **읽음 여부가 원본 필드와 다르기 때문**이다.
/// 워치에서 확인 버튼을 누르면 전송은 큐에 올라가지만 iPhone 이 새 스냅샷을 밀어 줄 때까지
/// `WatchNotice.isRead` 는 `false` 로 남는다. 그 간극을 ``PingInbox`` 의 낙관적 오버레이가
/// 메우고, 합쳐진 결과가 이 타입의 ``isRead`` 다.
struct WatchPingItem: Equatable, Identifiable, Sendable {

    // MARK: - Property

    let notice: WatchNotice
    /// 스냅샷의 `isRead` 에 워치 로컬 확인을 얹은 최종 읽음 상태.
    let isRead: Bool

    var id: String { notice.noticeId }
    var title: String { notice.title }
    var content: String { notice.content }
    var writer: String { notice.writer }
    var postedAt: Date { notice.postedAt }

    /// 필수 확인 공지. 긴급과 별개 축이라 행에서 텍스트 배지로만 표현한다.
    var isMustRead: Bool { notice.isMustRead }

    /// 긴급 공지 — **좌측 색바** 신호. 안읽음 점과 축이 달라 한 행에서 동시에 켜질 수 있다.
    var isUrgent: Bool { notice.isAlert }

    /// 색·위치 신호는 색각 이상·저시력 사용자에게 전달되지 않는다. 두 신호와 필수 여부를
    /// 모두 문장으로 풀어 VoiceOver 한 번에 낭독한다.
    var accessibilityLabel: String {
        var parts: [String] = [isRead ? "확인함" : "미확인"]
        if isUrgent { parts.append("긴급") }
        if isMustRead { parts.append("필수 확인") }
        parts.append(title)
        parts.append(writer)
        return parts.joined(separator: ", ")
    }

    // MARK: - Function

    /// 스냅샷 공지 목록을 표시 모델로 옮긴다.
    ///
    /// 정렬은 **최신순 하나뿐**이다. 미확인을 위로 끌어올리면 확인 버튼을 누른 직후 방금 읽은
    /// 행이 목록 아래로 튀어, 워치의 좁은 화면에서 어디를 봤는지 잃어버린다.
    static func list(
        from notices: [WatchNotice],
        readReceiptIDs: Set<String>
    ) -> [WatchPingItem] {
        notices
            .sorted { $0.postedAt > $1.postedAt }
            .map {
                WatchPingItem(
                    notice: $0,
                    isRead: $0.isRead || readReceiptIDs.contains($0.noticeId)
                )
            }
    }
}

#if DEBUG
extension WatchPingItem {

    static let unreadUrgent = WatchPingItem(
        notice: WatchNotice(
            noticeId: "301",
            title: "오늘 세션 장소 변경 — 3층 세미나실",
            content: "우천으로 야외 세션이 취소되어 3층 세미나실에서 진행합니다.\n출석 체크는 기존 시간 그대로입니다.",
            writer: "김운영",
            postedAt: .now.addingTimeInterval(-20 * 60),
            isMustRead: true,
            isAlert: true,
            isRead: false
        ),
        isRead: false
    )

    static let unreadNormal = WatchPingItem(
        notice: WatchNotice(
            noticeId: "302",
            title: "데모데이 팀 배정 결과 안내",
            content: "팀 배정 결과가 공지 게시판에 업로드되었습니다.",
            writer: "박기획",
            postedAt: .now.addingTimeInterval(-3 * 60 * 60),
            isMustRead: false,
            isAlert: false,
            isRead: false
        ),
        isRead: false
    )

    static let read = WatchPingItem(
        notice: WatchNotice(
            noticeId: "303",
            title: "워크북 제출 마감 D-1",
            content: "내일 23시 59분까지 워크북을 제출해 주세요.",
            writer: "이파트장",
            postedAt: .now.addingTimeInterval(-26 * 60 * 60),
            isMustRead: false,
            isAlert: false,
            isRead: true
        ),
        isRead: true
    )

    static let samples: [WatchPingItem] = [unreadUrgent, unreadNormal, read]
}
#endif
