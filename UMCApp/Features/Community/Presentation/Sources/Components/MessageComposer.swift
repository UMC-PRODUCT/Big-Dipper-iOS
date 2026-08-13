//
//  MessageComposer.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem
import CoreUIComponents

// MARK: - Constants

fileprivate enum Constants {
    static let sendButtonSize: CGFloat = 32
    static let placeholder = "메시지를 입력해주세요"
    static let lineLimit = 1...4
    /// 인용 칩 왼쪽의 세로 막대. 답장이라는 걸 아이콘 없이 알려 주는 표식이다.
    static let quoteBarWidth: CGFloat = 3
    /// 자동완성 오버레이 최대 높이 — 약 3.5행. 반쯤 걸친 행이 보여야 더 있다는 게 드러난다.
    static let mentionListMaxHeight: CGFloat = 176
    static let mentionRowAvatarSize = CGSize(width: 28, height: 28)
}

/// 하단 입력창.
///
/// 이미지 첨부·마이크는 업로드/음성 체인이 후속 PR 이라 버튼만 두고 비활성화한다 — 나중에 붙을 때
/// 입력창 높이가 바뀌지 않게 자리를 미리 잡아 둔다 (명세 FLOW 04 컴포저 구성).
///
/// 인용 칩과 `@` 자동완성은 입력줄 **위로 쌓는다**. 오버레이로 띄우면 마지막 말풍선을 가리는데,
/// 답장을 쓰는 순간에 가장 보고 싶은 게 바로 그 말풍선이다.
struct MessageComposer: View {

    // MARK: - Property

    @Binding var text: String

    let canSend: Bool
    /// 답장 인용 칩. `nil` 이면 칩 자리가 아예 없다 (시안 #22).
    let replyTarget: ThreadMessageReply?
    /// `@` 자동완성 후보. 비어 있으면 목록을 그리지 않는다.
    let mentionCandidates: [ThreadMember]
    let onSend: () -> Void
    let onCancelReply: () -> Void
    let onSelectMention: (ThreadMember) -> Void

    /// 전송 아이콘은 본문 크기를 따라 커지는데 원판이 고정이면 접근성 크기에서 글리프가 밖으로
    /// 삐져나온다. 원판도 같은 비율로 키운다.
    @ScaledMetric(relativeTo: .body) private var sendButtonSize = Constants.sendButtonSize

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if !mentionCandidates.isEmpty {
                mentionList
            }

            if let replyTarget {
                replyChip(replyTarget)
            }

            inputRow
        }
    }

    // MARK: - View Component

    private var inputRow: some View {
        HStack(alignment: .bottom, spacing: DefaultSpacing.spacing8) {
            Button {
                // 후속 PR: 이미지 첨부
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .foregroundStyle(Color.grey500)
            }
            .disabled(true)
            .accessibilityLabel("사진 첨부")

            TextField(Constants.placeholder, text: $text, axis: .vertical)
                .appFont(.subheadline)
                .lineLimit(Constants.lineLimit)
                .padding(.horizontal, DefaultSpacing.spacing12)
                .padding(.vertical, DefaultSpacing.spacing8)
                .background(Color.grey100, in: .capsule)

            Button {
                // 후속 PR: 음성 입력
            } label: {
                Image(systemName: "mic")
                    .foregroundStyle(Color.grey500)
            }
            .disabled(true)
            .accessibilityLabel("음성 입력")

            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .foregroundStyle(.white)
                    .frame(width: sendButtonSize, height: sendButtonSize)
                    .background(canSend ? Color.indigo500 : Color.grey300, in: .circle)
            }
            .disabled(!canSend)
            .accessibilityLabel("전송")
        }
        .padding(.horizontal, DefaultSpacing.spacing16)
        .padding(.vertical, DefaultSpacing.spacing8)
    }

    /// 답장 대상 요약 + 취소. 취소는 답장을 그만두는 유일한 경로라 44pt 를 채운다.
    private func replyChip(_ reply: ThreadMessageReply) -> some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Rectangle()
                .fill(Color.indigo500)
                .frame(width: Constants.quoteBarWidth)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                Text("\(reply.senderName)님에게 답장")
                    .appFont(.caption2, weight: .semibold, color: .indigo600)

                Text(reply.snippet)
                    .appFont(.caption1, color: .grey600)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: DefaultSpacing.spacing8)

            Button(action: onCancelReply) {
                Image(systemName: "xmark")
                    .foregroundStyle(Color.grey600)
                    .frame(
                        width: DefaultConstant.minimumTouchTarget,
                        height: DefaultConstant.minimumTouchTarget
                    )
                    .contentShape(.rect)
            }
            .accessibilityLabel("답장 취소")
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.leading, DefaultSpacing.spacing16)
        .background(Color.grey100)
    }

    /// `@` 자동완성. 후보가 많아도 입력창을 화면 밖으로 밀지 않게 높이를 묶어 스크롤한다.
    private var mentionList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(mentionCandidates) { member in
                    Button {
                        onSelectMention(member)
                    } label: {
                        mentionRow(member)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: Constants.mentionListMaxHeight)
        .background(Color.grey000)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func mentionRow(_ member: ThreadMember) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            RemoteImage(
                urlString: member.profileImageURL ?? "",
                size: Constants.mentionRowAvatarSize
            )

            Text(member.name)
                .appFont(.subheadline, color: .grey900)
                .lineLimit(1)

            if let part = member.part, !part.isEmpty {
                Text(part)
                    .appFont(.caption2, color: .grey500)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, DefaultSpacing.spacing16)
        .frame(minHeight: DefaultConstant.minimumTouchTarget)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
        .accessibilityHint("멘션으로 추가")
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    @Previewable @State var text = "@김"

    VStack {
        Spacer()

        MessageComposer(
            text: $text,
            canSend: true,
            replyTarget: ThreadMessageReply(
                messageId: "1",
                senderName: "김유엠",
                snippet: "오늘 스터디 7시에 시작합니다"
            ),
            mentionCandidates: [
                ThreadMember(
                    id: "1",
                    name: "김유엠",
                    part: "iOS",
                    profileImageURL: nil,
                    role: .owner
                ),
                ThreadMember(
                    id: "2",
                    name: "김메이커스",
                    part: "Web",
                    profileImageURL: nil,
                    role: .member
                )
            ],
            onSend: {},
            onCancelReply: {},
            onSelectMention: { _ in }
        )
    }
}
#endif
