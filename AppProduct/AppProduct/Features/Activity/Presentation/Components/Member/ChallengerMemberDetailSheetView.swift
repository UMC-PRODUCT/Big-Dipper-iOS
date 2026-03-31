//
//  ChallengerMemberDetailSheetView.swift
//  AppProduct
//
//  Created by 김미주 on 2/5/26.
//

import SwiftUI

struct ChallengerMemberDetailSheetView: View {
    // MARK: - Property

    @Environment(\.dismiss) private var dismiss
    var member: MemberManagementItem
    @State private var selectedGisu: Int

    init(member: MemberManagementItem) {
        self.member = member
        _selectedGisu = State(
            initialValue: member.generationPoints.map(\.gisu).max() ?? 0
        )
    }

    private enum Constants {
        static let tagPadding: EdgeInsets = .init(top: 4, leading: 8, bottom: 4, trailing: 8)
        static let boxPadding: EdgeInsets = .init(top: 12, leading: 0, bottom: 12, trailing: 0)
        static let listPadding: EdgeInsets = .init(top: 12, leading: 12, bottom: 12, trailing: 12)
        static let profileSize: CGSize = .init(width: 60, height: 60)

        static let baseHeight: CGFloat = 360
        static let emptyRecordHeight: CGFloat = 150
        static let recordRowHeight: CGFloat = 50
        static let maxVisibleRecords: Int = 5
        static let minSheetHeight: CGFloat = 420
        static let maxSheetHeight: CGFloat = 700

        static let summaryRowVerticalPadding: CGFloat = 12
        static let partTagOpacity: Double = 0.14
        static let partStrokeOpacity: Double = 0.4
        static let partStrokeWidth: CGFloat = 1
    }

    // MARK: - Computed Properties

    /// 현재 기수 표시 (마지막 기수)
    private var currentGeneration: String {
        if hasMultipleGenerations,
           let lastGisu = member.generationPoints.map(\.gisu).max() {
            return "\(lastGisu)기"
        }
        let gens = member.generation
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return gens.last ?? member.generation
    }

    /// 복수 기수 여부
    private var hasMultipleGenerations: Bool {
        member.generationPoints.count > 1
    }

    /// 현재 선택된 기수의 요약 데이터
    private var selectedSummary: GenerationPointSummary? {
        member.generationPoints.first { $0.gisu == selectedGisu }
    }

    /// 현재 선택된 기수의 상점
    private var displayRewardPoints: Double {
        selectedSummary?.reward ?? member.rewardPoints
    }

    /// 현재 선택된 기수의 벌점
    private var displayPenaltyPoints: Double {
        selectedSummary?.penalty ?? member.penalty
    }

    private var dynamicSheetHeight: CGFloat {
        let recordCount = member.attendanceRecords.count

        if recordCount == 0 {
            return Constants.baseHeight + Constants.emptyRecordHeight
        }

        let visibleRecords = min(recordCount, Constants.maxVisibleRecords)
        let recordsHeight = (CGFloat(visibleRecords) * Constants.recordRowHeight)
        + (CGFloat(max(0, visibleRecords - 1)) * DefaultSpacing.spacing8)

        let calculatedHeight = Constants.baseHeight + recordsHeight

        return max(Constants.minSheetHeight, min(calculatedHeight, Constants.maxSheetHeight))
    }

    private var scrollViewHeight: CGFloat {
        let recordCount = member.attendanceRecords.count

        if recordCount == 0 {
            return Constants.emptyRecordHeight
        }

        let visibleRecords = min(recordCount, Constants.maxVisibleRecords)
        let recordsHeight = (CGFloat(visibleRecords) * Constants.recordRowHeight)
        + (CGFloat(max(0, visibleRecords - 1)) * DefaultSpacing.spacing8)

        return recordsHeight
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing32) {
                memberInfoView

                summaryCardView

                recordView
            }
            .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .scrollContentBackground(.hidden)
            .presentationDetents([.height(dynamicSheetHeight)])
        }
    }

    // MARK: - SubView

    private var memberInfoView: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            RemoteImage(urlString: member.profile ?? "", size: Constants.profileSize)

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                Text("\(member.nickname)/\(member.name)")
                    .appFont(.bodyEmphasis)
                HStack(spacing: DefaultSpacing.spacing8) {
                    Text(member.part.name)
                        .appFont(.callout, color: member.part.color)
                        .padding(Constants.tagPadding)
                        .background(
                            member.part.color.opacity(Constants.partTagOpacity),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .stroke(
                                    member.part.color.opacity(Constants.partStrokeOpacity),
                                    lineWidth: Constants.partStrokeWidth
                                )
                        }
                    Text(member.school)
                        .appFont(.callout, color: .black)
                        .padding(Constants.tagPadding)
                        .background(.white, in: Capsule())
                    if member.managementTeam != .challenger {
                        ManagementTeamBadgePresenter(managementTeam: member.managementTeam)
                    }
                }
            }
        }
    }

    private var summaryCardView: some View {
        VStack(spacing: .zero) {
            summaryRow(title: "활동 기수") {
                if hasMultipleGenerations {
                    generationMenu
                } else {
                    Text(currentGeneration)
                        .appFont(.subheadlineEmphasis)
                }
            }

            Divider()

            summaryRow(title: "상점") {
                Text(String(format: "%.0f", displayRewardPoints))
                    .appFont(.subheadlineEmphasis, color: .green)
            }

            Divider()

            summaryRow(title: "벌점") {
                Text(String(format: "%.0f", displayPenaltyPoints))
                    .appFont(.subheadlineEmphasis, color: .red)
            }
        }
        .padding(.horizontal, Constants.listPadding.leading)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
        .glass()
    }

    private var generationMenu: some View {
        Menu {
            Picker("기수 선택", selection: $selectedGisu) {
                ForEach(member.generationPoints) { summary in
                    Text("\(summary.gisu)기")
                        .tag(summary.gisu)
                }
            }
        } label: {
            HStack(spacing: DefaultSpacing.spacing4) {
                Text("\(selectedGisu)기")
                    .appFont(.subheadlineEmphasis)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.grey500)
            }
        }
        .foregroundStyle(.primary)
    }

    // MARK: - Function

    private func summaryRow<Content: View>(
        title: String,
        @ViewBuilder value: () -> Content
    ) -> some View {
        HStack {
            Text(title)
                .appFont(.subheadline, color: .grey700)
            Spacer()
            value()
        }
        .padding(.vertical, Constants.summaryRowVerticalPadding)
    }

    private var recordView: some View {
        VStack(alignment: .leading) {
            Label("출석/활동 기록", systemImage: "exclamationmark.arrow.trianglehead.2.clockwise.rotate.90")
                .appFont(.title3Emphasis)

            if member.attendanceRecords.isEmpty {
                emptyRecordView
            } else {
                recordListView
            }
        }
    }

    private var emptyRecordView: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: "calendar.badge.exclamationmark")
                .appFont(.title1, color: .grey500)
            Text("아직 출석 기록이 없습니다")
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity)
        .frame(height: Constants.emptyRecordHeight)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
        .glass()
    }

    private var recordListView: some View {
        List(member.attendanceRecords, rowContent: { record in
            attendanceRecordRow(record)
                .listRowBackground(Color.clear)
        })
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .frame(height: scrollViewHeight)
        .background(.white, in: RoundedRectangle(cornerRadius: DefaultConstant.cornerRadius))
        .glass()
    }

    private func attendanceRecordRow(_ record: MemberAttendanceRecord) -> some View {
        HStack(spacing: DefaultSpacing.spacing16) {
            Text(record.status.displayText)
                .appFont(.subheadlineEmphasis, color: record.status.fontColor)
                .padding(Constants.tagPadding)
                .background(record.status.backgroundColor, in: Capsule())

            Text(record.sessionTitle)
                .appFont(.subheadline)
                .lineLimit(1)

            Spacer()
        }
    }
}

#Preview {
    Text("Preview")
        .sheet(isPresented: .constant(true), content: {
            ChallengerMemberDetailSheetView(
                member: .init(
                    profile: nil,
                    name: "김미주",
                    nickname: "마티",
                    generation: "7기, 8기, 9기",
                    school: "덕성여자대학교",
                    position: "Challenger",
                    part: .front(type: .ios),
                    penalty: 2,
                    rewardPoints: 3,
                    badge: false,
                    managementTeam: .schoolPartLeader,
                    attendanceRecords: [
                        MemberAttendanceRecord(
                            sessionTitle: "OT 및 Git 기초",
                            week: 1,
                            status: .present
                        ),
                        MemberAttendanceRecord(
                            sessionTitle: "iOS SwiftUI 기초",
                            week: 2,
                            status: .absent
                        ),
                        MemberAttendanceRecord(
                            sessionTitle: "네비게이션 & 데이터 플로우",
                            week: 3,
                            status: .late
                        ),
                    ],
                    penaltyHistory: [],
                    generationPoints: [
                        GenerationPointSummary(gisu: 7, reward: 1, penalty: 0),
                        GenerationPointSummary(gisu: 8, reward: 2, penalty: 1),
                        GenerationPointSummary(gisu: 9, reward: 0, penalty: 1)
                    ]
                ))
            })
}
