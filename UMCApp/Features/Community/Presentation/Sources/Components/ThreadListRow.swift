//
//  ThreadListRow.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    static let iconSize: CGFloat = 44
    static let iconCornerRadius: CGFloat = 12
    static let badgeMinWidth: CGFloat = 20
    static let capsuleVerticalPadding: CGFloat = 2
    static let previewLineLimit = 1
    static let emptyPreview = "아직 대화가 없어요"
}

/// 스레드 리스트 한 행.
///
/// 위 줄에 이모지·제목·카테고리 칩·상태 아이콘·시각·미읽음 배지, 아래 줄에 마지막 메시지.
struct ThreadListRow: View {

    // MARK: - Property

    let thread: CommunityThread

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: DefaultSpacing.spacing12) {
            icon

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                titleLine
                previewLine
            }
        }
        .padding(.vertical, DefaultSpacing.spacing8)
        .contentShape(.rect)
    }

    // MARK: - View Component

    private var icon: some View {
        Text(thread.displayIcon)
            .font(.app(.title2))
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .background(Color.grey100, in: .rect(cornerRadius: Constants.iconCornerRadius))
    }

    private var titleLine: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            Text(thread.title)
                .appFont(.subheadline, weight: .semibold, color: .grey900)
                .lineLimit(1)

            categoryChip

            if thread.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(Color.grey500)
                    .imageScale(.small)
            }
            if thread.isMuted {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(Color.grey500)
                    .imageScale(.small)
            }

            Spacer(minLength: DefaultSpacing.spacing4)

            if let lastMessage = thread.lastMessage {
                Text(lastMessage.createdAt.relativeListLabel)
                    .appFont(.caption1, color: .grey500)
            }
        }
    }

    private var categoryChip: some View {
        Text(thread.category.displayName)
            .appFont(.caption2, color: .indigo500)
            .padding(.horizontal, DefaultSpacing.spacing8)
            .padding(.vertical, Constants.capsuleVerticalPadding)
            .background(Color.indigo100, in: .capsule)
    }

    private var previewLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: DefaultSpacing.spacing8) {
            Text(previewText)
                .appFont(.footnote, color: .grey600)
                .lineLimit(Constants.previewLineLimit)

            Spacer(minLength: DefaultSpacing.spacing4)

            if let badge = thread.unreadBadge {
                // indigo500 은 다크 모드에서도 채도가 유지돼 대비색은 항상 흰색이다.
                Text(badge)
                    .appFont(.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, DefaultSpacing.spacing8)
                    .padding(.vertical, Constants.capsuleVerticalPadding)
                    .frame(minWidth: Constants.badgeMinWidth)
                    .background(Color.indigo500, in: .capsule)
            }
        }
    }

    private var previewText: String {
        guard let lastMessage = thread.lastMessage else { return Constants.emptyPreview }
        return "\(lastMessage.senderName): \(lastMessage.preview)"
    }
}

// MARK: - Date Label

private extension Date {

    /// 리스트용 짧은 시각. 오늘이면 시:분, 아니면 날짜.
    var relativeListLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = Calendar.current.isDateInToday(self) ? "a h:mm" : "M월 d일"
        return formatter.string(from: self)
    }
}
