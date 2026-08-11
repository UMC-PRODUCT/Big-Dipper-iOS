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
    static let deletedText = "삭제된 메시지예요"
}

/// 메시지 한 개.
///
/// 수신은 좌측(이름 표시), 발신은 우측. SYSTEM 은 좌우 구분 없이 중앙 캡션으로 그린다.
/// 삭제된 메시지는 목록에서 빼지 않고 톰스톤 문구로 남긴다 — 앞뒤 맥락이 끊기지 않게.
///
/// `isMine` 을 스스로 판단하지 않고 받는다. 판정 기준(`senderId` 대조)은 ViewModel 하나에만
/// 두고, 이 타입은 프리뷰·테스트에서 양쪽 모양을 바로 찍어 볼 수 있게 순수하게 남긴다.
struct MessageBubble: View {

    // MARK: - Property

    let message: ThreadMessage
    let isMine: Bool
    let onRetry: () -> Void

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

                // 이름·내용·시각은 한 덩어리로 읽어야 자연스럽다. 재시도 버튼은 이 밖에 있어
                // 합쳐도 접근 불가가 되지 않는다.
                VStack(alignment: isMine ? .trailing : .leading, spacing: DefaultSpacing.spacing4) {
                    if !isMine {
                        Text(message.senderName)
                            .appFont(.caption2, color: .grey600)
                    }
                    bubble
                    Text(Self.timeFormatter.string(from: message.createdAt))
                        .appFont(.caption2, color: .grey500)
                }
                .accessibilityElement(children: .combine)

                if !isMine {
                    Spacer(minLength: DefaultSpacing.spacing32)
                }
            }
            .padding(.vertical, DefaultSpacing.spacing4)
        }
    }

    // MARK: - View Component

    private var bubble: some View {
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
            }
            .accessibilityLabel("다시 보내기")

        case .sent:
            EmptyView()
        }
    }

    // MARK: - Computed Property

    private var bubbleBackground: Color {
        if message.isDeleted { return .grey100 }
        return isMine ? .indigo500 : .grey100
    }

    private var bubbleForeground: Color {
        if message.isDeleted { return .grey500 }
        return isMine ? .white : .grey900
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
            createdAt: base,
            deletedAt: deletedAt,
            deliveryState: deliveryState
        )
    }

    return VStack(spacing: 0) {
        MessageBubble(
            message: message(id: "1", content: "안녕하세요! 오늘 스터디 몇 시에 시작하나요?"),
            isMine: false,
            onRetry: {}
        )
        MessageBubble(
            message: message(id: "2", content: "7시에 시작합니다"),
            isMine: true,
            onRetry: {}
        )
        MessageBubble(
            message: message(id: "3", content: "보내는 중", deliveryState: .sending),
            isMine: true,
            onRetry: {}
        )
        MessageBubble(
            message: message(id: "4", content: "실패한 메시지", deliveryState: .failed),
            isMine: true,
            onRetry: {}
        )
        MessageBubble(
            message: message(id: "5", content: "지워진 내용", deletedAt: base),
            isMine: false,
            onRetry: {}
        )
        MessageBubble(
            message: message(id: "6", content: "김유엠님이 참여했어요", type: .system),
            isMine: false,
            onRetry: {}
        )
    }
    .padding(.horizontal, DefaultSpacing.spacing16)
}
#endif
