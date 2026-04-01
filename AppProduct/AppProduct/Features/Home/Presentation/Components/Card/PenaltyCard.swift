//
//  PenaltyCard.swift
//  AppProduct
//
//  Created by euijjang97 on 1/14/26.
//

import SwiftUI
import Charts

/// 홈 화면 상벌점 카드
///
/// 사용자의 기수별 상점/벌점 차트와 상세 기록을 카드 형태로 표시합니다.
struct PenaltyCard: View, Equatable {

    // MARK: - Properties

    /// 기수별 상벌점 데이터 리스트
    let generations: [GenerationData]

    /// 현재 표시 중인 탭(기수) 인덱스
    @State private var currentIndex: Int = 0
    /// 드래그 오프셋 (손가락 추적용)
    @State private var dragOffset: CGFloat = 0
    /// 수평 드래그 여부 (방향 잠금용)
    @State private var isHorizontalDrag: Bool?
    /// 팝오버 필터 (nil이면 닫힘)
    @State private var popoverFilter: PointLogFilter?
    /// chartAngleSelection 선택 값
    @State private var selectedChartAngle: Int?

    fileprivate enum PointLogFilter {
        case reward
        case penalty
    }

    // MARK: - Constants

    fileprivate enum Constants {
        /// 카드 전체 패딩
        static let padding: CGFloat = 20
        /// 스와이프 임계 거리
        static let swipeThreshold: CGFloat = 50
        /// 스와이프 임계 속도
        static let velocityThreshold: CGFloat = 300
        /// 차트 크기
        static let chartSize: CGFloat = 120
        /// 도넛 내부 비율
        static let innerRadius: CGFloat = 0.6
    }

    // MARK: - Equtable
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.generations == rhs.generations
    }

    // MARK: - Init

    /// PenaltyCard 생성자
    /// - Parameter generations: 표시할 기수별 상벌점 데이터
    init(generations: [GenerationData]) {
        self.generations = generations
    }

    // MARK: - Body
    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing24, content: {
            GenTabBar(
                generations: generations.map { $0.gen },
                currentIndex: $currentIndex
            )

            cardContent
                .offset(x: dragOffset)
                .contentShape(.rect)
                .gesture(swipeGesture)
        })
        .animation(.smooth(duration: 0.3), value: currentIndex)
        .padding(Constants.padding)
        .clipped()
        .clipShape(.rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true))
        .glassEffect(.regular, in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
        .onAppear {
            clampCurrentIndex()
        }
        .onChange(of: generations.count) { _, _ in
            clampCurrentIndex()
        }
    }

    // MARK: - Function

    /// 현재 선택된 기수의 상벌점 차트 및 기록을 표시하는 콘텐츠 영역
    @ViewBuilder
    private var cardContent: some View {
        if generations.indices.contains(currentIndex) {
            let generation = generations[currentIndex]
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
                pointChart(generation: generation)
            }
            .padding(.horizontal, DefaultSpacing.spacing4)
            .id(currentIndex)
            .transition(.blurReplace)
        }
    }

    /// 상점/벌점 도넛 차트
    private func pointChart(generation: GenerationData) -> some View {
        let hasData = generation.rewardPoint != 0 || generation.penaltyPoint != 0
        let selectedFilter: PointLogFilter? = selectedChartAngle.map {
            $0 <= abs(generation.rewardPoint) ? .reward : .penalty
        }

        return HStack(spacing: DefaultSpacing.spacing24) {
            ZStack {
                Chart {
                    SectorMark(
                        angle: .value("상점", hasData ? abs(generation.rewardPoint) : 0),
                        innerRadius: .ratio(Constants.innerRadius),
                        angularInset: 2
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo400, .indigo600],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(selectedFilter == nil || selectedFilter == .reward ? 1.0 : 0.3)

                    SectorMark(
                        angle: .value("벌점", hasData ? abs(generation.penaltyPoint) : 0),
                        innerRadius: .ratio(Constants.innerRadius),
                        angularInset: 2
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.indigo100, .indigo300],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .opacity(selectedFilter == nil || selectedFilter == .penalty ? 1.0 : 0.3)

                    if !hasData {
                        SectorMark(
                            angle: .value("없음", 1),
                            innerRadius: .ratio(Constants.innerRadius)
                        )
                        .foregroundStyle(.grey200)
                    }
                }
                .chartLegend(.hidden)
                .frame(width: Constants.chartSize, height: Constants.chartSize)
                .chartAngleSelection(value: $selectedChartAngle)
                .onChange(of: selectedChartAngle) { _, newAngle in
                    guard hasData, let value = newAngle else { return }
                    popoverFilter = value <= abs(generation.rewardPoint) ? .reward : .penalty
                }

                VStack(spacing: 2) {
                    Text("\(generation.rewardPoint + generation.penaltyPoint)")
                        .appFont(.title2Emphasis, color: .grey900)
                    Text("총점")
                        .appFont(.caption2, color: .grey500)
                }
                .allowsHitTesting(false)
            }
            .popover(isPresented: Binding(
                get: { popoverFilter != nil },
                set: { if !$0 {
                    popoverFilter = nil
                    selectedChartAngle = nil
                }}
            )) {
                PointLogPopover(
                    logs: generation.pointLogs.filter {
                        popoverFilter == .reward ? $0.isReward : !$0.isReward
                    }
                )
                .presentationCompactAdaptation(.popover)
            }

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
                legendLabel(color: .indigo500, label: "상점", value: generation.rewardPoint)
                legendLabel(color: .indigo200, label: "벌점", value: generation.penaltyPoint)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// 범례 라벨
    private func legendLabel(color: Color, label: String, value: Int) -> some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .appFont(.subheadline, color: .grey600)
            Spacer()
            Text("\(value)")
                .appFont(.calloutEmphasis, color: .grey900)
        }
    }

    /// 기수 간 전환을 위한 수평 스와이프 제스처
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 15)
            .onChanged { value in
                if isHorizontalDrag == nil {
                    isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                }
                guard isHorizontalDrag == true else { return }

                let translation = value.translation.width
                let isAtLeadingEdge = currentIndex == 0 && translation > 0
                let isAtTrailingEdge = currentIndex == generations.count - 1 && translation < 0

                if isAtLeadingEdge || isAtTrailingEdge {
                    dragOffset = translation * 0.3
                } else {
                    dragOffset = translation
                }
            }
            .onEnded { value in
                defer { isHorizontalDrag = nil }
                guard isHorizontalDrag == true else { return }

                let translation = value.translation.width
                let velocity = value.predictedEndTranslation.width

                withAnimation(.smooth(duration: 0.3)) {
                    if (translation < -Constants.swipeThreshold || velocity < -Constants.velocityThreshold),
                       currentIndex < generations.count - 1 {
                        currentIndex += 1
                    } else if (translation > Constants.swipeThreshold || velocity > Constants.velocityThreshold),
                              currentIndex > 0 {
                        currentIndex -= 1
                    }
                    dragOffset = 0
                }
            }
    }

    private func clampCurrentIndex() {
        guard !generations.isEmpty else {
            currentIndex = 0
            return
        }
        currentIndex = min(max(currentIndex, 0), generations.count - 1)
    }
}

/// 상벌점 기록 팝오버
fileprivate struct PointLogPopover: View {

    // MARK: - Property

    let logs: [PointLogItem]

    private enum Constants {
        static let circleDiameter: CGFloat = 8
        static let popoverPadding: CGFloat = 16
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text("상세 기록")
                .appFont(.footnoteEmphasis, color: .grey900)

            ForEach(logs) { log in
                HStack(spacing: DefaultSpacing.spacing8) {
                    Circle()
                        .fill(log.isReward ? Color.indigo500 : Color.indigo200)
                        .frame(
                            width: Constants.circleDiameter,
                            height: Constants.circleDiameter
                        )

                    Text(log.reason)
                        .appFont(.subheadline, color: .grey900)

                    Spacer()

                    Text(log.isReward ? "+\(abs(log.point))" : "-\(abs(log.point))")
                        .appFont(.subheadline, color: log.isReward ? .indigo500 : .indigo300)

                    Text(log.date)
                        .appFont(.footnote, color: .grey500)
                }
            }
        }
        .padding(Constants.popoverPadding)
        .glassEffect(.clear, in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
    }
}

/// 기수 선택 탭 바
fileprivate struct GenTabBar: View {

    // MARK: - Properties

    /// 표시할 기수 목록
    let generations: [Int]
    /// 현재 선택된 인덱스 바인딩
    @Binding var currentIndex: Int

    private enum Constants {
        /// 탭 텍스트 패딩
        static let textPadding: EdgeInsets = .init(top: 8, leading: 16, bottom: 8, trailing: 16)
        /// 인디케이터 간격
        static let indicatorSpacing: CGFloat = 4
        /// 인디케이터 지름
        static let indicatorDiameter: CGFloat = 8
    }

    // MARK: - Body
    var body: some View {
        let titleText = generations.indices.contains(currentIndex)
            ? "\(generations[currentIndex])th 활동 상태"
            : "활동 상태"

        HStack(spacing: DefaultSpacing.spacing16) {
            Text(titleText)
                .appFont(.footnoteEmphasis, color: .indigo600)
                .padding(Constants.textPadding)
                .background(.indigo100, in: .capsule)

            Spacer()

            HStack(spacing: Constants.indicatorSpacing) {
                ForEach(generations.indices, id: \.self) { index in
                    Circle()
                        .fill(currentIndex == index ? Color.indigo500 : Color.indigo200)
                        .frame(width: Constants.indicatorDiameter, height: Constants.indicatorDiameter)
                        .onTapGesture {
                            withAnimation {
                                currentIndex = index
                            }
                        }
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    PenaltyCard(generations: [
        GenerationData(
            gisuId: 0,
            gen: 11,
            penaltyPoint: 6,
            rewardPoint: 5,
            pointLogs: [
                .init(reason: "스터디 지각", date: "03.26", point: -2, isReward: false),
                .init(reason: "워크북 미제출", date: "03.27", point: -4, isReward: false),
                .init(reason: "우수 워크북", date: "03.28", point: 2, isReward: true)
            ],
            penaltyLogs: [
                .init(reason: "지각", date: "03.26", penaltyPoint: 1),
                .init(reason: "과제 미제출", date: "03.27", penaltyPoint: 1),
                .init(reason: "과제 미제출", date: "03.27", penaltyPoint: 2)
            ]
        ),
        GenerationData(
            gisuId: 0,
            gen: 12,
            penaltyPoint: 1,
            rewardPoint: 3,
            pointLogs: [
                .init(reason: "지각", date: "03.14", point: -1, isReward: false),
            ],
            penaltyLogs: [
                .init(reason: "지각", date: "03.14", penaltyPoint: 1),
            ]
        ),
        GenerationData(
            gisuId: 0,
            gen: 13,
            penaltyPoint: 0,
            rewardPoint: 0,
            pointLogs: [],
            penaltyLogs: []
        )
    ])
}
