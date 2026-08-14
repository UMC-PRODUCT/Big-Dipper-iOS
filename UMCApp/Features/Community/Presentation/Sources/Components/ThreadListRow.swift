//
//  ThreadListRow.swift
//  CommunityPresentation
//

import SwiftUI
import CommunityDomain
import CoreDesignSystem

// MARK: - Constants

fileprivate enum Constants {
    static let badgeMinWidth: CGFloat = 20
    static let capsuleVerticalPadding: CGFloat = 2
    static let previewLineLimit = 1
    /// 접근성 크기에서는 한 줄로 자르면 제목이 몇 글자만 남아 두 줄까지 허용한다.
    static let accessibilityLineLimit = 2
    static let emptyPreview = "아직 대화가 없어요"
    /// 시스템 블루를 그대로 깔면 칩이 제목보다 튄다. 애플 tinted 버튼과 같은 농도로 낮춘다.
    static let chipTintOpacity: Double = 0.12
}

/// 스레드 리스트 한 행. 흰 카드 하나가 곧 한 행이다.
///
/// 위 줄에 이모지·제목·카테고리 칩·상태 아이콘·시각, 아래 줄에 마지막 메시지와 미읽음 배지.
///
/// 안읽음/읽음은 **미읽음 배지 하나로만** 가른다. 카카오톡·iMessage 와 같은 방식으로, 배경·제목·
/// 아이콘·미리보기·시각은 두 상태가 완전히 같다.
struct ThreadListRow: View {

    // MARK: - Property

    let thread: CommunityThread

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @ScaledMetric(relativeTo: .title2) private var scaledIconSize = ThreadCardMetrics.iconSize

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
        .threadCard()
        .contentShape(.rect(cornerRadius: DefaultConstant.cornerRadius))
    }

    // MARK: - Computed Property

    private var isCompactMetadata: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var lineLimit: Int {
        isCompactMetadata ? Constants.accessibilityLineLimit : 1
    }

    // MARK: - View Component

    private var icon: some View {
        Text(thread.displayIcon)
            .font(.app(.title2))
            .frame(
                width: min(scaledIconSize, ThreadCardMetrics.maxIconSize),
                height: min(scaledIconSize, ThreadCardMetrics.maxIconSize)
            )
            .background(Color.grey100, in: .circle)
    }

    private var titleLine: some View {
        HStack(spacing: DefaultSpacing.spacing4) {
            Text(thread.title)
                .appFont(.subheadline, weight: .semibold, color: .grey900)
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

    /// 시스템 블루를 쓴다. 다크 모드 대비는 시스템이 맞춰 주므로 별도 토큰을 만들지 않는다.
    private var categoryChip: some View {
        Text(thread.category.displayName)
            .appFont(.caption2)
            .foregroundStyle(Color.blue)
            .lineLimit(1)
            .padding(.horizontal, DefaultSpacing.spacing8)
            .padding(.vertical, Constants.capsuleVerticalPadding)
            .background(Color.blue.opacity(Constants.chipTintOpacity), in: .capsule)
    }

    @ViewBuilder
    private var timeLabel: some View {
        if let lastMessage = thread.lastMessage {
            Text(lastMessage.createdAt.relativeListLabel)
                .appFont(.caption1, color: .grey500)
                .lineLimit(1)
        }
    }

    private var previewLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: DefaultSpacing.spacing8) {
            Text(previewText)
                .appFont(.footnote, color: .grey500)
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
        thread.lastMessage?.preview ?? Constants.emptyPreview
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
