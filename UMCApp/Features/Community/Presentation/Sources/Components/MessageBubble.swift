//
//  MessageBubble.swift
//  CommunityPresentation
//

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
    let onRetry: () -> Void
    let onReact: (String) -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

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

    private var bubbleContent: some View {
        Text(message.isDeleted ? Constants.deletedText : message.content)
            .appFont(.subheadline)
            .foregroundStyle(bubbleForeground)
            .italic(message.isDeleted)
            .padding(.horizontal, DefaultSpacing.spacing12)
            .padding(.vertical, DefaultSpacing.spacing8)
            .background(bubbleBackground, in: .rect(cornerRadius: Constants.cornerRadius))
            .frame(
                maxWidth: Constants.maxBubbleWidth,
                alignment: isMine ? .trailing : .leading
            )
    }

    /// 이모지 팔레트는 메뉴 맨 위 한 줄로 낸다. `ControlGroup` + `.compactMenu` 가 네이티브
    /// 가로 배열을 그려 주므로 오버레이를 직접 띄우지 않는다.
    ///
    /// 답장·신고는 각각 후속 이슈 소관이라 지금 넣으면 아무 일도 하지 않는 항목이 된다.
    @ViewBuilder
    private var contextMenuItems: some View {
        ControlGroup {
            ForEach(Constants.reactionEmojis, id: \.self) { emoji in
                Button(emoji) { onReact(emoji) }
            }
        }
        .controlGroupStyle(.compactMenu)

        Button(action: onCopy) {
            Label("복사", systemImage: "doc.on.doc")
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

    // MARK: - Function

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
            onRetry: {},
            onReact: { _ in },
            onCopy: {},
            onDelete: {}
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
        bubble(message(id: "4", content: "보내는 중", deliveryState: .sending), isMine: true)
        bubble(message(id: "5", content: "실패한 메시지", deliveryState: .failed), isMine: true)
        bubble(message(id: "6", content: "지워진 내용", deletedAt: base), isMine: false)
        bubble(message(id: "7", content: "김유엠님이 참여했어요", type: .system), isMine: false)
    }
    .padding(.horizontal, DefaultSpacing.spacing16)
}
#endif
