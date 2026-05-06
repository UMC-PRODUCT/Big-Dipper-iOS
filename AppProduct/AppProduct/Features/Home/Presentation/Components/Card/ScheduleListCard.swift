//
//  ScheduleListCard.swift
//  AppProduct
//
//  Created by euijjang97 on 1/18/26.
//

import SwiftUI
import Playgrounds

/// 일정 정보를 리스트 형태로 보여주는 카드 뷰
///
/// 일정 제목, 소제목, 그리고 자동 분류된 카테고리 아이콘을 표시합니다.
/// `ScheduleClassifierRepository`를 통해 일정 제목을 분석하여 적절한 카테고리를 설정합니다.
struct ScheduleListCard: View, Equatable {

    // MARK: - Properties

    /// 표시할 일정 데이터 (V2 통합 모델)
    let data: ScheduleDetailData

    /// 부모에서 미리 분류한 카테고리 (nil이면 카드 내부에서 분류)
    private let resolvedCategory: ScheduleIconCategory?

    /// 일정 카테고리 (자동 분류됨, 기본값: .general)
    @State var category: ScheduleIconCategory = .general

    /// 분류 로딩 상태
    @State var isLoading: Bool

    /// 카드마다 모델/캐시를 재로딩하지 않도록 분류기를 공유합니다.
    private static let sharedUseCase: ClassifyScheduleUseCase = {
        let repository = ScheduleClassifierRepositoryImpl()
        return ClassifyScheduleUseCaseImpl(repository: repository)
    }()

    private enum Constants {
        /// 아이콘 패딩
        static let iconPadding: CGFloat = 8
        /// 카드 전체 패딩
        static let padding: EdgeInsets = .init(top: 20, leading: 16, bottom: 20, trailing: 16)
        /// 카드 모서리 반경
        static let cornerRadius: CGFloat = 24
        /// 라인 limit 제한
        static let lineLimit: Int = 1
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.data == rhs.data
    }

    // MARK: - Init

    /// ScheduleListCard 생성자
    /// - Parameter data: 표시할 일정 데이터
    init(data: ScheduleDetailData, category: ScheduleIconCategory? = nil) {
        self.data = data
        self.resolvedCategory = category
        _category = State(initialValue: category ?? .general)
        _isLoading = State(initialValue: category == nil)
    }

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing24, content: {
            CardIconImage(image: category.symbol, color: category.color, isLoading: $isLoading)
            infoContent
            Spacer()
            chevron
        })
        .padding(Constants.padding)
        .background {
            ConcentricRectangle(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true)
                .fill(.white)
                .glass()
        }
        .task(id: data.scheduleId) {
            if let resolvedCategory {
                category = resolvedCategory
                isLoading = false
                return
            }

            isLoading = true
            category = await Self.sharedUseCase.execute(title: data.name)
            isLoading = false
        }
    }

    /// 일정 내용 정보 (제목, 부제목)
    private var infoContent: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8, content: {
            // 일정 제목
            Text(data.name)
                .appFont(.calloutEmphasis, color: .grey900)
                .lineLimit(Constants.lineLimit)
            // 참여 상태 + D-Day
            Text(statusText)
                .appFont(.subheadline, color: .grey600)
        })
    }

    private var statusText: String {
        let status = data.participationStatusText
        return status == "종료됨" ? status : "\(status) · \(data.dDayText)"
    }

    private var chevron: some View {
        Image(systemName: DefaultConstant.chevronForwardImage)
            .renderingMode(.template)
            .foregroundStyle(.grey900)
            .padding(Constants.iconPadding)
    }
}

#Preview {
    VStack {
        ScheduleListCard(data: .init(
            scheduleId: 1,
            name: "컨퍼런스",
            description: "",
            tags: [],
            startsAt: .now.addingTimeInterval(60 * 60 * 24 * 7),
            endsAt: .now.addingTimeInterval(60 * 60 * 24 * 7 + 3600),
            location: nil,
            participants: [],
            authorMemberId: 0,
            attendancePolicy: nil,
            attendanceStatus: nil,
            isAttendanceChecked: false,
            isOnline: true,
            isParticipant: true
        ))
        ScheduleListCard(data: .init(
            scheduleId: 2,
            name: "데모데이",
            description: "",
            tags: [],
            startsAt: .now.addingTimeInterval(-60 * 60 * 24 * 14),
            endsAt: .now.addingTimeInterval(-60 * 60 * 24 * 14 + 3600),
            location: nil,
            participants: [],
            authorMemberId: 0,
            attendancePolicy: nil,
            attendanceStatus: nil,
            isAttendanceChecked: false,
            isOnline: false,
            isParticipant: false
        ))
    }
    .safeAreaPadding(.horizontal, 16)
}
