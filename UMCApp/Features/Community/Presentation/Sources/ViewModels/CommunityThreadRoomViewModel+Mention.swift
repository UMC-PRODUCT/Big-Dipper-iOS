//
//  CommunityThreadRoomViewModel+Mention.swift
//  CommunityPresentation
//

import Foundation
import CommunityDomain

/// 답장 인용과 `@` 멘션.
///
/// 둘 다 "초안에 딸린 값" 이라 한 곳에 모은다 — 전송 한 번으로 함께 실려 나가고, 전송이 끝나면
/// 함께 비워진다. 본문 문자열이 진실의 원천이고 고른 목록은 그 보조다: `@이름` 을 지우면 멘션도
/// 빠진다(``mentionedMembers(in:)``). 반대로 하면 본문에 없는 사람에게 알림만 가는 상태가 된다.
///
/// 멘션 알림 발송은 **서버 선행 작업**이다 — `CommunityThreadMentionedEvent` 는 발행되지만
/// 리스너가 아직 없다(#1140 서버 확인). 클라이언트는 대상 id 를 정확히 실어 보내는 데까지 한다.
extension CommunityThreadRoomViewModel {

    // MARK: - Reply Function

    /// 답장 메뉴를 띄울지. 아직 서버가 모르는 메시지(`.sending`/`.failed`)의 id 는 내가 만든
    /// UUID 라 `replyToId` 로 보내면 서버가 거절한다 — `canDelete`·`canReport` 와 같은 이유다.
    public func canReply(_ message: ThreadMessage) -> Bool {
        !message.isDeleted && message.deliveryState == .sent && message.type != .system
    }

    /// 컨텍스트 메뉴의 "답장" 진입점 (#1139 롱프레스 메뉴 → 시안 #22 인용 칩).
    ///
    /// 스니펫을 여기서 잘라 둔다. 서버도 응답에 잘린 스니펫을 실어 주지만 그건 전송 뒤 이야기라,
    /// 칩에 띄울 문구는 로컬에서 만들어야 한다.
    public func requestReply(_ message: ThreadMessage) {
        guard canReply(message) else { return }

        replyTarget = ThreadMessageReply(
            messageId: message.id,
            senderName: message.senderName,
            snippet: Self.snippet(message.content)
        )
    }

    /// 인용 칩의 취소 버튼. 고른 멘션은 본문에 남아 있으므로 함께 지우지 않는다.
    public func cancelReply() {
        replyTarget = nil
    }

    /// 말풍선 인용 블록 탭 → 원본으로 스크롤 (시안 #38).
    ///
    /// 아직 불러오지 않은 과거 메시지는 목적지가 없어 아무 일도 하지 않는다. "그 메시지로 점프"
    /// 하려면 특정 messageId 를 포함하는 페이지를 주는 서버 API 가 필요한데 계약에 없다.
    public func scrollToQuoted(_ messageId: String) {
        guard messages.contains(where: { $0.id == messageId }) else { return }
        quoteScrollTarget = messageId
    }

    /// 화면이 스크롤을 마친 뒤 호출한다. 비워 두지 않으면 같은 인용을 두 번 눌러도 반응이 없다.
    public func clearQuoteScrollTarget() {
        quoteScrollTarget = nil
    }

    // MARK: - Mention Function

    /// 초안이 바뀔 때마다 자동완성 후보를 다시 고른다.
    ///
    /// 커서 위치를 받지 않고 **마지막 `@` 토큰**만 본다. `TextField` 가 커서를 넘겨주지 않아
    /// 정확한 토큰을 알려면 `UIViewRepresentable` 로 내려가야 하는데, 채팅 입력에서 문장 중간에
    /// 돌아가 멘션을 끼워 넣는 경우는 드물어 그 비용을 지불하지 않는다.
    public func draftDidChange() {
        guard let query = Self.mentionQuery(in: draft) else {
            mentionCandidates = []
            return
        }

        guard let members = memberCache else {
            loadMembersForMention()
            return
        }
        mentionCandidates = Self.candidates(from: members, query: query)
    }

    /// 자동완성 행을 골랐을 때. 마지막 `@` 토큰을 `@이름 ` 으로 갈아 끼운다.
    public func selectMention(_ member: ThreadMember) {
        guard let range = Self.mentionTokenRange(in: draft) else { return }

        draft.replaceSubrange(range, with: "@\(member.name) ")
        // 같은 사람을 두 번 골라도 전송 목록은 한 번만 실린다. 서버도 중복을 제거하지만
        // 본문에 이름이 두 번 있는 경우와 구분해 둘 이유가 없다.
        if !pickedMentions.contains(where: { $0.id == member.id }) {
            pickedMentions.append(member)
        }
        mentionCandidates = []
    }

    // MARK: - Internal Function

    /// 전송에 실을 멘션. 고른 뒤 본문에서 이름을 지웠다면 대상에서 뺀다.
    func mentionedMembers(in content: String) -> [ThreadMessageMention] {
        pickedMentions
            .filter { content.contains("@\($0.name)") }
            .map { ThreadMessageMention(memberId: $0.id, name: $0.name) }
    }

    /// 전송 직후 초안에 딸린 상태를 함께 비운다.
    func clearComposerAttachments() {
        replyTarget = nil
        pickedMentions = []
        mentionCandidates = []
    }

    // MARK: - Private Function

    /// 참여자 목록은 첫 `@` 에서 한 번만 읽는다.
    ///
    /// 실패해도 안내하지 않는다 — 사용자가 요청한 동작이 아니라 입력 보조라, 알림을 띄우면
    /// 타이핑 중에 흐름이 끊긴다. 캐시를 비워 둔 채 다음 `@` 에서 다시 시도한다.
    private func loadMembersForMention() {
        guard memberLoadTask == nil else { return }

        memberLoadTask = Task { [weak self] in
            guard let self else { return }
            let members = try? await useCase.loadMembers(threadId: threadId)
            memberLoadTask = nil
            guard let members else { return }
            memberCache = members
            // 기다리는 동안 초안이 바뀌었을 수 있다. 지금 값으로 다시 판정한다.
            draftDidChange()
        }
    }

    // MARK: - Static Function

    /// 마지막 `@` 토큰의 검색어. 토큰이 없으면 `nil` (오버레이를 닫는다).
    ///
    /// `@` 는 단어 시작에서만 연다 — 이메일 주소를 치는 동안 후보가 튀어나오지 않게.
    /// 공백이 들어가면 토큰이 끝난 것으로 본다. 이름에 공백이 있는 계정은 이 규칙으로 찾을 수
    /// 없지만, 직접 이름을 다 쳐서 보내면 멘션 없이 본문만 나간다(전송 자체는 막히지 않는다).
    static func mentionQuery(in draft: String) -> String? {
        guard let range = mentionTokenRange(in: draft) else { return nil }
        return String(draft[draft.index(after: range.lowerBound)..<range.upperBound])
    }

    /// 갈아 끼울 구간(`@` 포함 ~ 초안 끝).
    static func mentionTokenRange(in draft: String) -> Range<String.Index>? {
        guard let atIndex = draft.lastIndex(of: "@") else { return nil }

        if atIndex != draft.startIndex {
            let previous = draft[draft.index(before: atIndex)]
            guard previous.isWhitespace else { return nil }
        }

        let query = draft[draft.index(after: atIndex)...]
        guard !query.contains(where: { $0.isWhitespace }) else { return nil }
        return atIndex..<draft.endIndex
    }

    /// 후보 목록. 검색어가 비어 있으면(`@` 만 친 상태) 전원을 보여 준다.
    static func candidates(from members: [ThreadMember], query: String) -> [ThreadMember] {
        guard !query.isEmpty else { return members }
        return members.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    /// 인용 칩·인용 블록에 띄울 한 줄 요약. 개행이 남으면 칩이 두 줄로 벌어진다.
    static func snippet(_ content: String) -> String {
        let flattened = content
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard flattened.count > Constants.snippetLength else { return flattened }
        return String(flattened.prefix(Constants.snippetLength)) + "…"
    }
}

// MARK: - Constants

fileprivate enum Constants {
    /// 칩 한 줄에 들어가는 대략의 길이. 넘치면 `lineLimit` 이 잘라 주지만, 그 전에 줄여 두면
    /// 낙관적 버블과 서버가 준 스니펫의 길이가 크게 어긋나지 않는다.
    static let snippetLength = 40
}
