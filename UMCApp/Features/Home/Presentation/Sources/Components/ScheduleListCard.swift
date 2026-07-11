import CoreDesignSystem
import CoreUIComponents
import HomeDomain
import SwiftUI
import UMCFoundation

/// 선택한 날짜의 일정 한 건을 리스트 형태로 보여주는 카드.
///
/// - Note: 제목 기반 자동 카테고리 분류(ML)는 이 슬라이스(#914) 범위 밖으로, 항상
///   ``ScheduleIconCategory/general`` 아이콘을 표시한다. 분류 기능은 후속 이슈에서 추가한다.
struct ScheduleListCard: View, Equatable {

    // MARK: - Property

    let data: ScheduleDetailData

    private let category: ScheduleIconCategory = .general

    fileprivate enum Constants {
        static let iconPadding: CGFloat = 8
        static let padding = EdgeInsets(top: 20, leading: 16, bottom: 20, trailing: 16)
        static let lineLimit = 1
    }

    // MARK: - Equatable

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data == rhs.data
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
        ScheduleListCard(data: ScheduleDetailData(
            scheduleId: "1",
            name: "컨퍼런스",
            description: "",
            tags: [],
            startsAt: .now.addingTimeInterval(60 * 60 * 24 * 7),
            endsAt: .now.addingTimeInterval(60 * 60 * 24 * 7 + 3600),
            isParticipant: true
        ))
        ScheduleListCard(data: ScheduleDetailData(
            scheduleId: "2",
            name: "데모데이",
            description: "",
            tags: [],
            startsAt: .now.addingTimeInterval(-60 * 60 * 24 * 14),
            endsAt: .now.addingTimeInterval(-60 * 60 * 24 * 14 + 3600),
            isParticipant: false
        ))
    }
    .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
}
