//
//  MessageBubble.swift
//  CommunityPresentation
//

import Foundation
import SwiftUI
import CommunityDomain
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    static let cornerRadius: CGFloat = 16
    /// 버블 최대 폭. `UIScreen.main` 은 iOS 26 에서 사용할 수 없고, 화면 비율을 쓰려면
    /// 컨테이너 폭을 위에서 내려받는 배선이 붙는다. 아이폰 폭(320~440pt)에서 고정 280pt 면
    /// 시안 비율(약 72%)과 맞고, 큰 화면에서는 줄 길이가 짧아져 오히려 읽기 좋다.
    static let maxBubbleWidth: CGFloat = 280
    /// HIG 최소 탭 타깃. 재시도는 전송 실패에서 벗어나는 유일한 컨트롤이라 아이콘 크기로 두면
    /// 미스탭 비용이 크다.
    static let minimumTapTarget: CGFloat = 44
    static let deletedText = "삭제된 메시지예요"
    /// 인용 블록 왼쪽 세로 막대. 컴포저 인용 칩과 같은 두께로 맞춰 둔다.
    static let quoteBarWidth: CGFloat = 3
    /// 말풍선 안에 들어가는 블록이라 바깥 모서리(16)보다 작게 준다.
    static let quoteCornerRadius: CGFloat = 8
    /// 반응 팔레트. 고정 목록만 노출해 사용자 자유 입력 경로를 아예 두지 않는다 —
    /// 그래서 Genmoji(표준 유니코드가 아닌 이미지 글리프)가 서버로 나갈 수 없다.
    static let reactionEmojis = ["👍", "❤️", "😂", "😮", "😢", "🙏"]
}

/// 메시지 한 개.
///
/// 수신은 좌측(이름 표시), 발신은 우측. SYSTEM 은 좌우 구분 없이 중앙 캡션으로 그린다.
/// 삭제된 메시지는 목록에서 빼지 않고 톰스톤 문구로 남긴다 — 앞뒤 맥락이 끊기지 않게.
///
/// `isMine`/`canDelete` 를 스스로 판단하지 않고 받는다. 판정 기준(`senderId` 대조, 권한)은
/// ViewModel 하나에만 두고, 이 타입은 프리뷰·테스트에서 양쪽 모양을 바로 찍어 볼 수 있게
/// 순수하게 남긴다.
struct MessageBubble: View {

    // MARK: - Property

    let message: ThreadMessage
    let isMine: Bool
    let canDelete: Bool
    let canReport: Bool
    let onRetry: () -> Void
    let onReact: (String) -> Void
    let onReply: () -> Void
    /// 인용 블록 탭 → 원본 messageId 로 스크롤 (시안 #38).
    let onQuoteTap: (String) -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onReport: () -> Void

    // MARK: - Body

    var body: some View {
        if message.type == .system {
            systemMessage
        } else {
            HStack(alignment: .bottom, spacing: DefaultSpacing.spacing8) {
                if isMine {
                    Spacer(minLength: DefaultSpacing.spacing32)
                    deliveryIndicator
                }

                VStack(
                    alignment: isMine ? .trailing : .leading,
                    spacing: DefaultSpacing.spacing4
                ) {
                    // 이름과 본문은 한 덩어리로 읽어야 자연스럽다. 반응 칩은 각각 눌러야 하는
                    // 버튼이라 이 묶음 밖에 둔다 — 합치면 개별 토글이 VoiceOver 에서 사라진다.
                    VStack(
                        alignment: isMine ? .trailing : .leading,
                        spacing: DefaultSpacing.spacing4
                    ) {
                        if !isMine {
                            Text(message.senderName)
                                .appFont(.caption2, color: .grey600)
                        }
                        bubble
                    }
                    .accessibilityElement(children: .combine)

                    if showsReactions {
                        reactionChips
                    }

                    Text(Self.timeFormatter.string(from: message.createdAt))
                        .appFont(.caption2, color: .grey500)
                }

                if !isMine {
                    Spacer(minLength: DefaultSpacing.spacing32)
                }
            }
            .padding(.vertical, DefaultSpacing.spacing4)
        }
    }

    // MARK: - View Component

    /// 톰스톤에는 메뉴를 붙이지 않는다 — 지워진 본문을 복사하거나 다시 지울 이유가 없다.
    @ViewBuilder
    private var bubble: some View {
        if message.isDeleted {
            bubbleContent
        } else {
            bubbleContent.contextMenu { contextMenuItems }
        }
    }

    /// 본문은 항상 그대로 남기고, 내부 링크가 있으면 그 아래에 카드를 덧붙인다.
    ///
    /// 링크 문자열을 카드로 **치환**하지 않는 이유는 카드가 실패할 수 있기 때문이다. 원문을
    /// 지워 두면 메타 조회가 실패한 순간 링크에 닿을 방법이 사라진다 — 남겨 두면 그 경우가
    /// 그냥 "카드 없는 텍스트 링크" 가 된다.
    private var bubbleContent: some View {
        VStack(
            alignment: isMine ? .trailing : .leading,
            spacing: DefaultSpacing.spacing8
        ) {
            // 대상이 삭제되면 서버가 `replyTo` 를 통째로 `null` 로 준다 — 그때는 인용 없이
            // 본문만 남는다. 빈 인용 블록을 그려 두면 무엇을 가리켰는지 알 수 없는 껍데기가 된다.
            if let reply = message.replyTo, !message.isDeleted {
                quoteBlock(reply)
            }

            Text(bubbleText)
                .appFont(.subheadline)
                .foregroundStyle(bubbleForeground)
                .italic(message.isDeleted)
                .tint(linkTint)

            ForEach(cardLinks, id: \.self) { link in
                MessageLinkCard(link: link)
            }
        }
        .padding(.horizontal, DefaultSpacing.spacing12)
        .padding(.vertical, DefaultSpacing.spacing8)
        .background(bubbleBackground, in: .rect(cornerRadius: Constants.cornerRadius))
        .frame(
            maxWidth: Constants.maxBubbleWidth,
            alignment: isMine ? .trailing : .leading
        )
    }

    /// 답장 대상 요약 (시안 #38).
    ///
    /// 원문을 다시 찾아 올리지 않는다 — 서버가 스니펫을 잘라서 함께 내려주므로 이 세 필드로
    /// 다 그려진다. 탭하면 원본으로 스크롤하지만, 아직 안 불러온 과거라면 아무 일도 하지 않는다.
    private func quoteBlock(_ reply: ThreadMessageReply) -> some View {
        Button {
            onQuoteTap(reply.messageId)
        } label: {
            HStack(spacing: DefaultSpacing.spacing8) {
                Rectangle()
                    .fill(quoteAccent)
                    .frame(width: Constants.quoteBarWidth)

                VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                    Text(reply.senderName)
                        .appFont(.caption2, weight: .semibold)
                        .foregroundStyle(quoteAccent)

                    Text(reply.snippet)
                        .appFont(.caption2)
                        .foregroundStyle(quoteForeground)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, DefaultSpacing.spacing4)
            .padding(.trailing, DefaultSpacing.spacing8)
            .background(quoteBackground, in: .rect(cornerRadius: Constants.quoteCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reply.senderName)님의 메시지에 답장, \(reply.snippet)")
        .accessibilityHint("원본 메시지로 이동")
    }

    /// 이모지 팔레트는 메뉴 맨 위 한 줄로 낸다. `ControlGroup` + `.compactMenu` 가 네이티브
    /// 가로 배열을 그려 주므로 오버레이를 직접 띄우지 않는다.
    ///
    /// 신고에 `.destructive` 를 주지 않는다 — 지우는 동작이 아니고, 운영진 권한이라 삭제와
    /// 신고가 함께 뜨는 자리에서 빨강이 둘이면 어느 쪽이 되돌릴 수 없는지가 흐려진다.
    @ViewBuilder
    private var contextMenuItems: some View {
        ControlGroup {
            ForEach(Constants.reactionEmojis, id: \.self) { emoji in
                Button(emoji) { onReact(emoji) }
            }
        }
        .controlGroupStyle(.compactMenu)

        // 아직 서버가 모르는 메시지는 답장 대상이 될 수 없다 — 보낼 id 가 내가 만든 UUID 다.
        if message.deliveryState == .sent {
            Button(action: onReply) {
                Label("답장", systemImage: "arrowshape.turn.up.left")
            }
        }

        Button(action: onCopy) {
            Label("복사", systemImage: "doc.on.doc")
        }

        if canReport {
            Button(action: onReport) {
                Label("신고", systemImage: "exclamationmark.bubble")
            }
        }

        if canDelete {
            Button(role: .destructive, action: onDelete) {
                Label("삭제", systemImage: "trash")
            }
        }
    }

    /// 말풍선 아래 붙는 반응 칩. 칩을 다시 누르면 같은 토글이 돈다.
    private var reactionChips: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            ForEach(message.reactions, id: \.emoji) { reaction in
                Button {
                    onReact(reaction.emoji)
                } label: {
                    chipLabel(reaction)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Self.reactionLabel(reaction))
            }
        }
    }

    private func chipLabel(_ reaction: ThreadMessageReaction) -> some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            Text(reaction.emoji)
                .appFont(.caption1)
            Text(reaction.count)
                .appFont(.caption2, color: reaction.reactedByMe ? .indigo600 : .grey600)
        }
        .padding(.horizontal, DefaultSpacing.spacing8)
        .padding(.vertical, DefaultSpacing.spacing4)
        .background(reaction.reactedByMe ? Color.indigo100 : Color.grey100, in: .capsule)
        .overlay {
            Capsule()
                .strokeBorder(reaction.reactedByMe ? Color.indigo500 : Color.clear)
        }
        // 칩 자체는 캡슐 크기로 두고 탭 영역만 44pt 로 넓힌다. 시각적으로 키우면 말풍선보다
        // 반응이 더 커 보인다.
        .frame(
            minWidth: Constants.minimumTapTarget,
            minHeight: Constants.minimumTapTarget
        )
        .contentShape(.rect)
    }

    private var systemMessage: some View {
        Text(message.content)
            .appFont(.caption1, color: .grey500)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DefaultSpacing.spacing8)
    }

    /// 전송 상태 표시. 실패했을 때만 손댈 거리가 있으므로 그때만 버튼이 된다.
    @ViewBuilder
    private var deliveryIndicator: some View {
        switch message.deliveryState {
        case .sending:
            ProgressView()
                .controlSize(.mini)
                .accessibilityLabel("전송 중")

        case .failed:
            Button(action: onRetry) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.red500)
                    .frame(
                        minWidth: Constants.minimumTapTarget,
                        minHeight: Constants.minimumTapTarget
                    )
                    .contentShape(.rect)
            }
            .accessibilityLabel("다시 보내기")

        case .sent:
            EmptyView()
        }
    }

    // MARK: - Computed Property

    /// 톰스톤에는 반응이 남아 있어도 그리지 않는다 — 지워진 말풍선에 붙은 칩은 누를 수 없다.
    private var showsReactions: Bool {
        !message.isDeleted && !message.reactions.isEmpty
    }

    private var bubbleBackground: Color {
        if message.isDeleted { return .grey100 }
        return isMine ? .indigo500 : .grey100
    }

    private var bubbleForeground: Color {
        if message.isDeleted { return .grey500 }
        return isMine ? .white : .grey900
    }

    /// 링크 색. 발신 버블은 배경이 인디고라 인디고 링크가 묻힌다 — 밑줄과 함께 흰색으로 뺀다.
    /// 멘션도 같은 이유로 같은 색을 쓴다.
    private var linkTint: Color {
        isMine ? .white : .indigo600
    }

    /// 인용 블록 3색. 발신 버블은 배경이 인디고라 수신 버블과 같은 색을 쓰면 통째로 묻힌다.
    private var quoteAccent: Color {
        isMine ? .indigo100 : .indigo500
    }

    private var quoteForeground: Color {
        isMine ? .grey100 : .grey600
    }

    private var quoteBackground: Color {
        isMine ? .indigo600 : .grey200
    }

    private var bubbleText: AttributedString {
        guard !message.isDeleted else { return AttributedString(Constants.deletedText) }
        return Self.attributed(
            message.content,
            mentions: message.mentions,
            mentionTint: linkTint
        )
    }

    /// 카드로 그릴 내부 링크. 같은 링크를 여러 번 붙여 보낸 메시지에 카드를 겹쳐 세우지 않는다.
    private var cardLinks: [MessageLink] {
        guard !message.isDeleted else { return [] }

        var seen: Set<MessageLink> = []
        return MessageLink.segments(in: message.content).compactMap { segment in
            guard case .link(let link, _) = segment, seen.insert(link).inserted else {
                return nil
            }
            return link
        }
    }

    // MARK: - Function

    /// 본문을 링크가 살아 있는 문자열로 바꾸고 멘션을 강조한다.
    ///
    /// 내부 링크는 ``MessageLink`` 가 가려낸 구간에, 외부 URL 은 `NSDataDetector` 가 찾은
    /// 구간에 각각 `link` 속성을 건다. 어느 쪽이든 탭은 `openURL` 로 가고, 내부 링크인지는
    /// 그쪽에서 다시 판정한다 — 여기서는 "무엇이 링크인가" 만 정한다.
    private static func attributed(
        _ content: String,
        mentions: [ThreadMessageMention],
        mentionTint: Color
    ) -> AttributedString {
        var result = AttributedString()
        for segment in MessageLink.segments(in: content) {
            switch segment {
            case .text(let text):
                result += externalLinked(text)
            case .link(let link, let raw):
                result += linkRun(raw, url: link.url)
            }
        }
        return highlighted(result, mentions: mentions, tint: mentionTint)
    }

    /// 서버가 준 멘션 대상의 `@이름` 구간을 강조한다.
    ///
    /// 본문에 멘션 마크업이 없어(서버는 대상 목록만 따로 준다) 이름으로 되짚는 수밖에 없다.
    /// 그래서 우연히 같은 문자열이 본문에 또 있으면 그것도 함께 강조된다 — 색이 하나 더 붙는
    /// 것뿐이라 오탐 비용이 작고, 마크업 계약이 생기면 그때 구간 기반으로 바꾼다.
    ///
    /// 굵기는 `Font` 를 덮어쓰지 않고 `inlinePresentationIntent` 로 준다 — 폰트를 직접 넣으면
    /// 본문에 걸린 `appFont` 와 Dynamic Type 스케일이 그 구간만 어긋난다.
    private static func highlighted(
        _ base: AttributedString,
        mentions: [ThreadMessageMention],
        tint: Color
    ) -> AttributedString {
        var result = base
        // 찾기는 평문에서 한다. `AttributedString.Index` 는 속성만 바꿔도 무효가 될 수 있어
        // 위치를 문자 오프셋으로 들고 다니다가 쓸 때마다 새로 센다 — 본문 길이는 안 변한다.
        let text = String(base.characters)

        for mention in mentions where !mention.name.isEmpty {
            let token = "@\(mention.name)"
            var searchStart = text.startIndex

            while let found = text.range(of: token, range: searchStart..<text.endIndex) {
                let offset = text.distance(from: text.startIndex, to: found.lowerBound)
                let start = result.index(result.startIndex, offsetByCharacters: offset)
                let end = result.index(start, offsetByCharacters: token.count)

                result[start..<end].foregroundColor = tint
                result[start..<end].inlinePresentationIntent = .stronglyEmphasized
                searchStart = found.upperBound
            }
        }
        return result
    }

    private static func externalLinked(_ text: String) -> AttributedString {
        guard let detector = urlDetector else { return AttributedString(text) }

        var result = AttributedString()
        var cursor = text.startIndex

        for match in detector.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let range = Range(match.range, in: text), let url = match.url else { continue }
            if cursor < range.lowerBound {
                result += AttributedString(String(text[cursor..<range.lowerBound]))
            }
            result += linkRun(String(text[range]), url: url)
            cursor = range.upperBound
        }

        if cursor < text.endIndex {
            result += AttributedString(String(text[cursor...]))
        }
        return result
    }

    /// 링크 런. 밑줄까지 넣는 건 색만으로 구분이 안 되는 사용자를 위한 것이다.
    ///
    /// 속성 키를 스코프까지 적어 지정한다 — `run.link` 처럼 dynamic member 로 쓰면 Foundation·
    /// UIKit·SwiftUI 스코프가 같은 이름을 들고 있어 모호해질 수 있다.
    private static func linkRun(_ text: String, url: URL?) -> AttributedString {
        var run = AttributedString(text)
        guard let url else { return run }

        var attributes = AttributeContainer()
        attributes[AttributeScopes.FoundationAttributes.LinkAttribute.self] = url
        attributes[AttributeScopes.SwiftUIAttributes.UnderlineStyleAttribute.self] = .single
        run.mergeAttributes(attributes)
        return run
    }

    /// 외부 URL 탐지기. `http`/`https` 외에 `www.` 로 시작하는 표기도 잡는다.
    private static let urlDetector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.link.rawValue
    )

    /// 칩은 이모지 글리프만 읽히면 몇 개인지·내가 눌렀는지가 사라진다.
    private static func reactionLabel(_ reaction: ThreadMessageReaction) -> String {
        let base = "\(reaction.emoji) 반응 \(reaction.count)개"
        return reaction.reactedByMe ? "\(base), 내가 누름" : base
    }

    // MARK: - Formatter

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter
    }()
}

// MARK: - Preview

#if DEBUG
#Preview {
    let base = Date()

    func message(
        id: String,
        content: String,
        type: ThreadMessageType = .text,
        mentions: [ThreadMessageMention] = [],
        replyTo: ThreadMessageReply? = nil,
        reactions: [ThreadMessageReaction] = [],
        deliveryState: ThreadMessageDeliveryState = .sent,
        deletedAt: Date? = nil
    ) -> ThreadMessage {
        ThreadMessage(
            id: id,
            threadId: "1",
            senderId: "7",
            senderName: "김유엠",
            content: content,
            type: type,
            mentions: mentions,
            replyTo: replyTo,
            reactions: reactions,
            createdAt: base,
            deletedAt: deletedAt,
            deliveryState: deliveryState
        )
    }

    func bubble(
        _ message: ThreadMessage,
        isMine: Bool,
        canDelete: Bool = false
    ) -> MessageBubble {
        MessageBubble(
            message: message,
            isMine: isMine,
            canDelete: canDelete,
            canReport: !isMine,
            onRetry: {},
            onReact: { _ in },
            onReply: {},
            onQuoteTap: { _ in },
            onCopy: {},
            onDelete: {},
            onReport: {}
        )
    }

    return VStack(spacing: 0) {
        bubble(
            message(id: "1", content: "안녕하세요! 오늘 스터디 몇 시에 시작하나요?"),
            isMine: false
        )
        bubble(message(id: "2", content: "7시에 시작합니다"), isMine: true, canDelete: true)
        bubble(
            message(
                id: "3",
                content: "반응이 달린 메시지",
                reactions: [
                    ThreadMessageReaction(emoji: "👍", count: "3", reactedByMe: true),
                    ThreadMessageReaction(emoji: "🙏", count: "1", reactedByMe: false)
                ]
            ),
            isMine: false
        )
        // 외부 URL 은 카드가 아니라 텍스트 링크로만 남는다. 내부 링크 카드는 메타 조회에
        // DI 가 필요해 프리뷰에서는 다루지 않는다.
        bubble(
            message(id: "8", content: "자료는 여기 https://umc.it.kr/docs 참고해 주세요"),
            isMine: false
        )
        bubble(
            message(
                id: "9",
                content: "@김유엠 7시 맞아요",
                mentions: [ThreadMessageMention(memberId: "7", name: "김유엠")],
                replyTo: ThreadMessageReply(
                    messageId: "1",
                    senderName: "김유엠",
                    snippet: "안녕하세요! 오늘 스터디 몇 시에 시작하나요?"
                )
            ),
            isMine: false
        )
        bubble(
            message(
                id: "10",
                content: "@김유엠 확인했습니다",
                mentions: [ThreadMessageMention(memberId: "7", name: "김유엠")],
                replyTo: ThreadMessageReply(
                    messageId: "2",
                    senderName: "김메이커스",
                    snippet: "7시에 시작합니다"
                )
            ),
            isMine: true
        )
        bubble(message(id: "4", content: "보내는 중", deliveryState: .sending), isMine: true)
        bubble(message(id: "5", content: "실패한 메시지", deliveryState: .failed), isMine: true)
        bubble(message(id: "6", content: "지워진 내용", deletedAt: base), isMine: false)
        bubble(message(id: "7", content: "김유엠님이 참여했어요", type: .system), isMine: false)
    }
    .padding(.horizontal, DefaultSpacing.spacing16)
}
#endif
