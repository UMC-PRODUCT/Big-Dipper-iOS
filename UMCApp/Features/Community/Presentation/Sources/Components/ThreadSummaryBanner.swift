//
//  ThreadSummaryBanner.swift
//  CommunityPresentation
//

import SwiftUI
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    static let iconSize: CGFloat = 15
    static let closeIconSize: CGFloat = 12
    static let closeTapTarget: CGFloat = DefaultConstant.minimumTouchTarget
    static let sparklesImage = "sparkles"
    static let closeImage = "xmark"
    static let closeLabel = "요약 배너 닫기"
    static let hint = "핵심만 요약해 드려요"
    static let textLineLimit = 2
}

/// 미읽음이 많이 쌓인 방 상단에 뜨는 요약 진입점.
///
/// 메시지 리스트 위에 얹지 않고 리스트와 나란히 쌓는다. 오버레이로 띄우면 첫 버블을 가려
/// "안 읽은 메시지를 보러 왔는데 그게 가려지는" 상황이 된다.
struct ThreadSummaryBanner: View {

    // MARK: - Property

    let unreadCount: Int
    let onTap: () -> Void
    let onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Button(action: onTap) {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(systemName: Constants.sparklesImage)
                        .font(.system(size: Constants.iconSize, weight: .medium))
                        .foregroundStyle(Color.indigo500)

                    // 큰 글자 크기에서 한 줄로 묶으면 "읽지 않은 메시지 N개" 라는 핵심 수치부터
                    // 잘려 나간다. 두 줄까지 열어 두고 그 뒤에야 말줄임한다.
                    Text("읽지 않은 메시지 \(unreadCount)개 · \(Constants.hint)")
                        .appFont(.footnote, color: .grey700)
                        .lineLimit(Constants.textLineLimit)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)
                }
                // 글자 사이 빈 공간까지 눌러야 배너답다. 텍스트 폭만 히트 영역이 되면 잘 안 눌린다.
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: Constants.closeImage)
                    .font(.system(size: Constants.closeIconSize, weight: .semibold))
                    .foregroundStyle(Color.grey500)
                    .frame(width: Constants.closeTapTarget, height: Constants.closeTapTarget)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Constants.closeLabel)
        }
        .padding(.leading, DefaultSpacing.spacing12)
        .padding(.vertical, DefaultSpacing.spacing4)
        .glassEffect(
            .regular.interactive(),
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius))
        )
        .padding(.horizontal, DefaultSpacing.spacing16)
        .padding(.vertical, DefaultSpacing.spacing8)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ThreadSummaryBanner(unreadCount: 42, onTap: {}, onDismiss: {})
        .padding(.vertical, DefaultSpacing.spacing24)
}
#endif
