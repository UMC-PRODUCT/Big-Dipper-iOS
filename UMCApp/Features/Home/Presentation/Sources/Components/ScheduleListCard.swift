import CoreDesignSystem
import CoreUIComponents
import HomeDomain
import SwiftUI
import UMCFoundation

/// 선택한 날짜의 일정 한 건을 리스트 형태로 보여주는 카드.
///
/// - Note: 카테고리 아이콘은 이 뷰가 직접 분류하지 않고, 부모(`HomeViewModel`)가 제목 기반으로
///   분류한 결과(``ScheduleIconCategory``)를 주입받아 표시하는 dumb 컴포넌트다(#979).
struct ScheduleListCard: View, Equatable {

    // MARK: - Property

    let data: ScheduleDetailData
    let category: ScheduleIconCategory

    fileprivate enum Constants {
        static let iconPadding: CGFloat = 8
        static let padding = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)
        static let lineLimit = 1
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data == rhs.data && lhs.category == rhs.category
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing24) {
            CardIconImage(image: category.symbol, color: category.color, isLoading: .constant(false))
            infoContent
            Spacer()
            chevron
        }
        .padding(Constants.padding)
        .glassEffect(
            .regular,
            in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
        )
    }

    // MARK: - Component

    private var infoContent: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            Text(data.name)
                .appFont(.callout, weight: .semibold, color: .grey900)
                .lineLimit(Constants.lineLimit)
            Text(statusText)
                .appFont(.subheadline, color: .grey600)
        }
    }

    private var statusText: String {
        let status = data.participationStatusText
        return status == "종료됨" ? status : "\(status) · \(data.dDayText)"
    }

    private var chevron: some View {
        Image(systemName: DefaultConstant.chevronForwardImage)
            .renderingMode(.template)
            .foregroundStyle(Color.grey900)
            .padding(Constants.iconPadding)
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    VStack {
        ScheduleListCard(
            data: ScheduleDetailData(
                scheduleId: "1",
                name: "컨퍼런스",
                description: "",
                tags: [],
                startsAt: .now.addingTimeInterval(60 * 60 * 24 * 7),
                endsAt: .now.addingTimeInterval(60 * 60 * 24 * 7 + 3600),
                isParticipant: true
            ),
            category: .presentation
        )
        ScheduleListCard(
            data: ScheduleDetailData(
                scheduleId: "2",
                name: "데모데이",
                description: "",
                tags: [],
                startsAt: .now.addingTimeInterval(-60 * 60 * 24 * 14),
                endsAt: .now.addingTimeInterval(-60 * 60 * 24 * 14 + 3600),
                isParticipant: false
            ),
            category: .celebration
        )
    }
    .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
}
