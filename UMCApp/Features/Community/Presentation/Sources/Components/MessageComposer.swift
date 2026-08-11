//
//  MessageComposer.swift
//  CommunityPresentation
//

import SwiftUI
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    static let sendButtonSize: CGFloat = 32
    static let placeholder = "메시지를 입력해주세요"
    static let lineLimit = 1...4
}

/// 하단 입력창.
///
/// 이미지 첨부는 업로드 체인이 후속 PR 이라 버튼만 두고 비활성화한다 — 나중에 붙을 때
/// 입력창 높이가 바뀌지 않게 자리를 미리 잡아 둔다.
struct MessageComposer: View {

    // MARK: - Property

    @Binding var text: String

    let canSend: Bool
    let onSend: () -> Void

    /// 전송 아이콘은 본문 크기를 따라 커지는데 원판이 고정이면 접근성 크기에서 글리프가 밖으로
    /// 삐져나온다. 원판도 같은 비율로 키운다.
    @ScaledMetric(relativeTo: .body) private var sendButtonSize = Constants.sendButtonSize

    // MARK: - Body

    var body: some View {
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
}
