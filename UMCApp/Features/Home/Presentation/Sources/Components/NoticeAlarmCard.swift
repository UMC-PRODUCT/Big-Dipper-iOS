//
//  NoticeAlarmCard.swift
//  HomePresentation
//
//  Created by euijjang97 on 1/20/26.
//

import CoreDesignSystem
import HomeDomain
import SwiftUI
import UMCFoundation

/// 알림 보관함 행 카드 — 알림 타입별 아이콘/색상과 제목·내용·상대 시간을 표시한다.
struct NoticeAlarmCard: View {

    // MARK: - Property

    let notice: NoticeHistoryData

    // MARK: - Constants

    fileprivate enum Constants {
        static let iconSize: CGFloat = 24
        static let iconPadding: CGFloat = 8
        static let iconBackgroundOpacity: CGFloat = 0.2
        static let contentLineLimit: Int = 2
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .top, spacing: DefaultSpacing.spacing16) {
            icon
            info
        }
    }

    // MARK: - Component

    private var icon: some View {
        Image(systemName: notice.icon.image)
            .renderingMode(.template)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: Constants.iconSize, height: Constants.iconSize)
            .fontWeight(.semibold)
            .foregroundStyle(notice.icon.color)
            .padding(Constants.iconPadding)
            .background(notice.icon.color.opacity(Constants.iconBackgroundOpacity), in: .circle)
            .glassEffect(.clear, in: .circle)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            titleRow

            Text(notice.content)
                .appFont(.subheadline, color: .grey600)
                .multilineTextAlignment(.leading)
                .lineLimit(Constants.contentLineLimit)
        }
    }

    private var titleRow: some View {
        HStack {
            Text(notice.title)
                .appFont(.callout, weight: .semibold, color: .grey900)

            Spacer()

            Text(notice.createdAt.timeAgoText)
                .appFont(.footnote, color: .grey500)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: DefaultSpacing.spacing16) {
        NoticeAlarmCard(notice: NoticeHistoryData(
            title: "신입 모집 안내",
            content: "UMC 7기 신입 회원을 모집합니다. 많은 지원 부탁드립니다!",
            icon: .info,
            createdAt: Date(timeIntervalSinceNow: -3600)
        ))

        NoticeAlarmCard(notice: NoticeHistoryData(
            title: "회비 납부 완료",
            content: "1월 회비가 정상적으로 납부되었습니다.",
            icon: .success,
            createdAt: Date(timeIntervalSinceNow: -86400)
        ))

        NoticeAlarmCard(notice: NoticeHistoryData(
            title: "지각 경고",
            content: "이번 주 세미나에 10분 지각하셨습니다.",
            icon: .warning,
            createdAt: Date(timeIntervalSinceNow: -604800)
        ))

        NoticeAlarmCard(notice: NoticeHistoryData(
            title: "출석 미달",
            content: "출석률이 80% 미만입니다. 주의해주세요.",
            icon: .error,
            createdAt: Date(timeIntervalSinceNow: -2592000)
        ))
    }
    .padding()
    .modelContainer(for: [NoticeHistoryData.self], inMemory: true)
}
#endif
