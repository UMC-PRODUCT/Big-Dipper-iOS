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
    /// Dynamic Type 을 따라 커지되 여기서 멈춘다. 끝까지 따라가면 타일이 행 너비의 절반을
    /// 차지해 정작 제목이 밀린다.
    static let maxIconSize: CGFloat = 64
    static let iconCornerRadius: CGFloat = 12
    static let badgeMinWidth: CGFloat = 20
    static let capsuleVerticalPadding: CGFloat = 2
    static let previewLineLimit = 1
    /// 접근성 크기에서는 한 줄로 자르면 제목이 몇 글자만 남아 두 줄까지 허용한다.
    static let accessibilityLineLimit = 2
    static let emptyPreview = "아직 대화가 없어요"
    /// 이모지는 `foregroundStyle` 이 먹지 않아 색 토큰으로 딤할 수 없다. 읽은 행에서만 낮춘다.
    static let readIconOpacity: Double = 0.5
    /// 안읽음 행 배경 틴트. `indigo100` 을 그대로 깔면 목록 전체가 파래져 옅게 쓴다.
    static let unreadRowTintOpacity: Double = 0.45
}

/// 스레드 리스트 한 행.
///
/// 위 줄에 이모지·제목·카테고리 칩·상태 아이콘·시각, 아래 줄에 마지막 메시지와 미읽음 배지.
///
/// 안읽음/읽음은 **글자 굵기 · 색 · 아이콘 밝기 · 배경 틴트** 네 축으로 함께 가른다. 색 하나만
/// 쓰면 색각 이상이나 강한 햇빛 아래에서 두 상태가 붙어 보인다.
struct ThreadListRow: View {

    // MARK: - Property

    let thread: CommunityThread

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .title2) private var scaledIconSize = Constants.iconSize

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: DefaultSpacing.spacing12) {
            icon

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                titleLine
                previewLine
                // 접근성 크기에서는 칩과 시각을 제목 줄에서 내린다. 한 줄에 두면 제목이
                // 몇 글자만 남고 칩이 행을 넘긴다.
                if isCompactMetadata {
                    metadataLine
                }
            }
        }
        .padding(.vertical, DefaultSpacing.spacing8)
        .contentShape(.rect)
    }

    // MARK: - Function

    /// 안읽음 행 배경 틴트. 행 안이 아니라 `listRowBackground` 가 칠한다 — 셀 좌우 여백까지
    /// 덮어야 띠가 끊겨 보이지 않는다.
    static func rowTint(for thread: CommunityThread) -> Color {
        thread.isUnread ? Color.indigo100.opacity(Constants.unreadRowTintOpacity) : .clear
    }

    // MARK: - Computed Property

    private var isCompactMetadata: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var titleColor: AppColor {
        thread.isUnread ? .grey900 : .grey600
    }

    private var previewColor: AppColor {
        thread.isUnread ? .grey700 : .grey500
    }

    private var lineLimit: Int {
        isCompactMetadata ? Constants.accessibilityLineLimit : 1
    }

    // MARK: - View Component

    private var icon: some View {
        Text(thread.displayIcon)
            .font(.app(.title2))
            .opacity(thread.isUnread ? 1 : Constants.readIconOpacity)
            .frame(
                width: min(scaledIconSize, Constants.maxIconSize),
                height: min(scaledIconSize, Constants.maxIconSize)
            )
            .background(
                thread.isUnread ? Color.indigo100 : Color.grey100,
                in: .rect(cornerRadius: Constants.iconCornerRadius)
            )
    }

    private var titleLine: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            Text(thread.title)
                .appFont(
                    .subheadline,
                    weight: thread.isUnread ? .semibold : .regular,
                    color: titleColor
                )
                .lineLimit(lineLimit)
                // 칩·아이콘이 먼저 자리를 가져가면 제목이 말줄임만 남는다.
                .layoutPriority(1)

            if !isCompactMetadata {
                categoryChip
            }

            // 행 전체가 Button 이라 자식 레이블이 합쳐진다. 레이블을 주지 않으면
            // 한국어 제목 사이에 SF Symbol 기본 영문 이름이 그대로 읽힌다.
            if thread.isPinned {
                Image(systemName: "pin.fill")
                    .foregroundStyle(Color.grey500)
                    .imageScale(.small)
                    .accessibilityLabel("고정됨")
            }
            if thread.isMuted {
                Image(systemName: "bell.slash.fill")
                    .foregroundStyle(Color.grey500)
                    .imageScale(.small)
                    .accessibilityLabel("알림 꺼짐")
            }

            Spacer(minLength: DefaultSpacing.spacing4)

            if !isCompactMetadata {
                timeLabel
            }
        }
    }

    private var categoryChip: some View {
        Text(thread.category.displayName)
            .appFont(.caption2, color: .indigo500)
            .lineLimit(1)
            .padding(.horizontal, DefaultSpacing.spacing8)
            .padding(.vertical, Constants.capsuleVerticalPadding)
            .background(Color.indigo100, in: .capsule)
    }

    @ViewBuilder
    private var timeLabel: some View {
        if let lastMessage = thread.lastMessage {
            Text(lastMessage.createdAt.relativeListLabel)
                .appFont(.caption1, color: thread.isUnread ? .grey600 : .grey500)
                .lineLimit(1)
        }
    }

    private var previewLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: DefaultSpacing.spacing8) {
            Text(previewText)
                .appFont(.footnote, color: previewColor)
                .lineLimit(isCompactMetadata ? Constants.accessibilityLineLimit
                                             : Constants.previewLineLimit)

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
                    .accessibilityLabel("안읽음 \(badge)개")
            }
        }
    }

    /// 접근성 크기 전용 셋째 줄. 제목 줄에서 내려온 칩과 시각을 담는다.
    private var metadataLine: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            categoryChip
            timeLabel
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
