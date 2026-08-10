//
//  NoticeVoteCard.swift
//  NoticePresentation
//
//  Created by 이예지 on 6/1/26.
//

import SwiftUI
import CoreDI
import CoreDesignSystem
import CoreUIComponents
import NoticeDomain

/// 공지 상세에서 투표를 표시하는 카드 컴포넌트
///
/// 투표 전에도 결과 게이지를 표시하며, 투표 후 응답 수정과
/// 실명 투표 시 투표자 명단 보기를 지원합니다.
public struct NoticeVoteCard: View {

    // MARK: - Property

    public let vote: NoticeVote
    public let isSubmitting: Bool
    public let container: DIContainer
    @State private var selectedOptionIds: Set<String> = []
    @State private var isEditingVote: Bool = false
    @State private var isVotingMode: Bool = false
    @State private var voterSheetOption: VoteOption?
    @State private var showAllVotersSheet: Bool = false
    public let onVote: ([String]) -> Void
    public let onUpdateVote: ([String]) -> Void

    // MARK: - Constants

    fileprivate enum Constants {
        static let innerPadding: CGFloat = 25
        static let dividerHeight: CGFloat = 10
        static let progressHeight: CGFloat = 8
        static let capsulePadding: CGFloat = 8
        static let capsuleOpacity: Double = 0.3
        static let voteBtnVPadding: CGFloat = 8
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
            headerSection
            optionsSection
            footerSection
        }
        .padding(Constants.innerPadding)
        .background {
            ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
            .fill(Color(.systemGroupedBackground))
        }
        .sheet(item: $voterSheetOption) { option in
            VoteVoterListSheet(
                optionTitle: option.title,
                memberIds: option.selectedMemberIds,
                container: container
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAllVotersSheet) {
            VoteAllVotersSheet(
                options: vote.options,
                container: container
            )
            .presentationDetents([.medium, .large])
        }
        .onChange(of: vote) {
            if isEditingVote {
                isEditingVote = false
            }
            if isVotingMode && vote.hasUserVoted {
                isVotingMode = false
            }
        }
    }

    // MARK: - HeaderSection

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            HStack {
                Label("투표", systemImage: "chart.bar.fill")
                    .appFont(.callout, weight: .semibold)
                    .foregroundStyle(Color.black)

                Spacer()

                statusBadge
            }
            .padding(.bottom, DefaultSpacing.spacing4)

            Text(vote.question)
                .appFont(.body, weight: .semibold)
                .foregroundStyle(Color.black)

            HStack(spacing: DefaultSpacing.spacing8) {
                Text(vote.allowMultipleChoices ? "복수선택" : "단일선택")
                    .appFont(.footnote, color: .grey600)

                Divider()
                    .frame(height: Constants.dividerHeight)

                Text(vote.isAnonymous ? "익명" : "실명")
                    .appFont(.footnote, color: .grey600)

                Spacer()

                Label(vote.formattedPeriod, systemImage: "calendar")
                    .appFont(.footnote, color: .grey600)
            }
        }
    }

    // MARK: - StatusBadge

    private var statusBadge: some View {
        Group {
            switch vote.status {
            case .notStarted:
                Text("시작 전")
                    .appFont(.footnote, weight: .semibold, color: .grey700)
                    .padding(Constants.capsulePadding)
                    .background(Color.grey400.opacity(Constants.capsuleOpacity))
                    .clipShape(Capsule())
            case .active:
                Text("진행중")
                    .appFont(.footnote, weight: .semibold, color: .green)
                    .padding(Constants.capsulePadding)
                    .background(Color.green.opacity(Constants.capsuleOpacity))
                    .clipShape(Capsule())
                    .glassEffect(
                        .clear,
                        in: .rect(
                            corners: .concentric(minimum: DefaultConstant.concentricRadius),
                            isUniform: true
                        )
                    )
            case .ended:
                Text("마감")
                    .appFont(.footnote, weight: .semibold, color: .red)
                    .padding(Constants.capsulePadding)
                    .background(Color.red.opacity(Constants.capsuleOpacity))
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - OptionsSection

    private var optionsSection: some View {
        VStack(spacing: DefaultSpacing.spacing12) {
            ForEach(vote.options) { option in
                if canSelectOption {
                    Button(action: {
                        withAnimation(.default) {
                            toggleOption(option.id)
                        }
                    }) {
                        VoteSelectableResultRow(
                            option: option,
                            totalVotes: vote.totalVotes,
                            isSelected: selectedOptionIds.contains(option.id),
                            isAnonymous: vote.isAnonymous,
                            onVotersTapped: { handleVotersTapped(option) }
                        )
                    }
                    .disabled(isSubmitting)
                } else {
                    VoteResultRow(
                        option: option,
                        totalVotes: vote.totalVotes,
                        isUserSelected: vote.userVotedOptionIds.contains(option.id),
                        isAnonymous: vote.isAnonymous,
                        onVotersTapped: { handleVotersTapped(option) }
                    )
                }
            }
        }
    }

    /// 옵션 선택이 가능한 상태인지 여부
    private var canSelectOption: Bool {
        guard vote.status == .active else { return false }
        if vote.hasUserVoted {
            return isEditingVote
        }
        return isVotingMode
    }

    // MARK: - FooterSection

    private var footerSection: some View {
        VStack(spacing: DefaultSpacing.spacing8) {
            if vote.status == .active {
                if !vote.hasUserVoted && !isVotingMode {
                    // 미투표 + 결과 보기: 투표 참여 버튼
                    Button(action: {
                        withAnimation(.default) {
                            isVotingMode = true
                        }
                    }) {
                        Text("투표하기")
                            .appFont(.subheadline, weight: .semibold, color: .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Constants.voteBtnVPadding)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.indigo500)
                } else if !vote.hasUserVoted && isVotingMode {
                    // 투표 선택 모드: 투표 완료 버튼
                    voteSubmitButton(
                        title: "투표 완료",
                        allowEmpty: false
                    ) {
                        onVote(Array(selectedOptionIds))
                    }
                } else if isEditingVote {
                    // 수정 모드: 수정 완료 버튼 (빈 선택 허용 → 투표 해제)
                    voteSubmitButton(
                        title: "수정 완료",
                        allowEmpty: true
                    ) {
                        onUpdateVote(Array(selectedOptionIds))
                    }
                } else {
                    // 투표 완료 + 수정 가능: 투표 수정 버튼
                    Button(action: {
                        withAnimation(.default) {
                            selectedOptionIds = Set(vote.userVotedOptionIds)
                            isEditingVote = true
                        }
                    }) {
                        Text("투표 수정")
                            .appFont(.subheadline, weight: .semibold, color: .indigo500)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Constants.voteBtnVPadding)
                    }
                    .buttonStyle(.glass)
                    .tint(.indigo500)
                }
            }

            if !vote.isAnonymous && (Int(vote.totalParticipants) ?? 0) > 0 {
                Button(action: { showAllVotersSheet = true }) {
                    HStack(spacing: DefaultSpacing.spacing4) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 11))
                        Text("총 \(vote.totalParticipants)명 참여")
                    }
                    .appFont(.footnote, color: .indigo500)
                }
            } else {
                Text("총 \(vote.totalParticipants)명 참여")
                    .appFont(.footnote, color: .grey600)
            }
        }
    }

    private func voteSubmitButton(
        title: String,
        allowEmpty: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Group {
                if isSubmitting {
                    ProgressView()
                        .tint(.indigo500)
                } else {
                    Text(title)
                        .appFont(.subheadline, weight: .semibold, color: .white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Constants.voteBtnVPadding)
        }
        .buttonStyle(.glassProminent)
        .tint(.indigo500)
        .disabled((!allowEmpty && selectedOptionIds.isEmpty) || isSubmitting)
    }

    // MARK: - Function

    private func toggleOption(_ optionId: String) {
        if vote.allowMultipleChoices {
            if selectedOptionIds.contains(optionId) {
                selectedOptionIds.remove(optionId)
            } else {
                selectedOptionIds.insert(optionId)
            }
        } else {
            if selectedOptionIds.contains(optionId) {
                selectedOptionIds.remove(optionId)
            } else {
                selectedOptionIds = [optionId]
            }
        }
    }

    private func handleVotersTapped(_ option: VoteOption) {
        guard !vote.isAnonymous, (Int(option.voteCount) ?? 0) > 0 else { return }
        voterSheetOption = option
    }
}


// MARK: - VoteOptionRow

/// 투표 선택 행 (투표 전)
public struct VoteOptionRow: View {

    // MARK: - Property

    public let option: VoteOption
    public let isSelected: Bool
    public let allowMultiple: Bool

    // MARK: - Constant

    fileprivate enum Constants {
        static let mainPadding: CGFloat = 12
        static let bgOpacity: Double = 0.5
    }

    // MARK: - Body

    public var body: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            Image(systemName: isSelected ? "circle.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.indigo500 : Color.grey400)
                .appFont(.title3)
                .glassEffect(.clear)

            Text(option.title)
                .appFont(.callout, color: .black)

            Spacer()
        }
        .padding(Constants.mainPadding)
        .background(
            isSelected
                ? Color.indigo200.opacity(Constants.bgOpacity)
                : Color(.systemBackground).opacity(Constants.bgOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
    }
}


// MARK: - VoteSelectableResultRow

/// 결과 게이지를 표시하면서도 선택 가능한 투표 행 (미투표 + 진행중 / 수정 모드)
public struct VoteSelectableResultRow: View {

    // MARK: - Property

    public let option: VoteOption
    public let totalVotes: Int
    public let isSelected: Bool
    public let isAnonymous: Bool
    public var onVotersTapped: (() -> Void)?

    // MARK: - Constants

    fileprivate enum Constants {
        static let progressHeight: CGFloat = 8
        static let innerPadding: CGFloat = 18
        static let bgOpacity: Double = 0.5
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            topSection
            gaugeSection
            voterCountSection
        }
        .padding(Constants.innerPadding)
        .background(
            isSelected
                ? Color.indigo200.opacity(Constants.bgOpacity)
                : Color(.systemBackground).opacity(Constants.bgOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
    }

    private var topSection: some View {
        HStack {
            Image(systemName: isSelected ? "circle.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.indigo500 : Color.grey400)
                .appFont(.title3)

            Text(option.title)
                .appFont(.body, weight: isSelected ? .semibold : .regular, color: .black)

            Spacer()

            Text(String(format: "%.1f%%", option.percentage(totalVotes: totalVotes)))
                .appFont(.callout, weight: .semibold, color: isSelected ? .indigo700 : .grey700)
        }
    }

    private var gaugeSection: some View {
        Gauge(value: option.percentage(totalVotes: totalVotes), in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .gaugeStyle(.linearCapacity)
        .tint(isSelected ? Color.indigo500 : Color.grey400)
        .frame(height: Constants.progressHeight)
    }

    private var voterCountSection: some View {
        Group {
            if !isAnonymous && (Int(option.voteCount) ?? 0) > 0 {
                Button(action: { onVotersTapped?() }) {
                    Text("\(option.voteCount)명")
                        .appFont(.footnote, color: .indigo500)
                        .underline()
                }
            } else {
                Text("\(option.voteCount)명")
                    .appFont(.footnote, color: .grey600)
            }
        }
    }
}


// MARK: - VoteResultRow

/// 투표 결과 행 (투표 후 / 종료)
public struct VoteResultRow: View {

    // MARK: - Property

    public let option: VoteOption
    public let totalVotes: Int
    public let isUserSelected: Bool
    public let isAnonymous: Bool
    public var onVotersTapped: (() -> Void)?

    // MARK: - Constants

    fileprivate enum Constants {
        static let progressHeight: CGFloat = 8
        static let innerPadding: CGFloat = 18
        static let bgOpacity: Double = 0.5
    }

    // MARK: - Body

    public var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            topSection
            gaugeSection
            voterCountSection
        }
        .padding(Constants.innerPadding)
        .background(
            isUserSelected
                ? Color.indigo200.opacity(Constants.bgOpacity)
                : Color(.systemBackground).opacity(Constants.bgOpacity)
        )
        .clipShape(RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius))
    }

    private var topSection: some View {
        HStack {
            Text(option.title)
                .appFont(.body, weight: isUserSelected ? .semibold : .regular, color: .black)

            Spacer()

            if isUserSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.indigo500)
                    .appFont(.callout)
            }

            Text(String(format: "%.1f%%", option.percentage(totalVotes: totalVotes)))
                .appFont(.callout, weight: .semibold, color: isUserSelected ? .indigo700 : .grey700)
        }
    }

    private var gaugeSection: some View {
        Gauge(value: option.percentage(totalVotes: totalVotes), in: 0...100) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .gaugeStyle(.linearCapacity)
        .tint(isUserSelected ? Color.indigo500 : Color.grey400)
        .frame(height: Constants.progressHeight)
    }

    private var voterCountSection: some View {
        Group {
            if !isAnonymous && (Int(option.voteCount) ?? 0) > 0 {
                Button(action: { onVotersTapped?() }) {
                    Text("\(option.voteCount)명")
                        .appFont(.footnote, color: .indigo500)
                        .underline()
                }
            } else {
                Text("\(option.voteCount)명")
                    .appFont(.footnote, color: .grey600)
            }
        }
    }
}


// MARK: - Preview

#if DEBUG
#Preview("투표 가능 - 단일선택/익명", traits: .sizeThatFitsLayout) {
    NoticeVoteCard(
        vote: NoticeVote(
            id: "poll1",
            question: "다음 해커톤 주제로 어떤 것이 좋을까요?",
            options: [
                VoteOption(id: "1", title: "AI/머신러닝", voteCount: "45"),
                VoteOption(id: "2", title: "블록체인", voteCount: "23"),
                VoteOption(id: "3", title: "IoT", voteCount: "18"),
                VoteOption(id: "4", title: "게임 개발", voteCount: "34")
            ],
            startDate: Date(timeIntervalSinceNow: -86400),
            endDate: Date(timeIntervalSinceNow: 86400 * 7),
            allowMultipleChoices: false,
            isAnonymous: true,
            userVotedOptionIds: []
        ),
        isSubmitting: false,
        container: .init(),
        onVote: { _ in },
        onUpdateVote: { _ in }
    )
    .padding()
}

#Preview("투표 완료 - 단일선택/실명", traits: .sizeThatFitsLayout) {
    NoticeVoteCard(
        vote: NoticeVote(
            id: "poll2",
            question: "다음 해커톤 주제로 어떤 것이 좋을까요?",
            options: [
                VoteOption(id: "1", title: "AI/머신러닝", voteCount: "45"),
                VoteOption(id: "2", title: "블록체인", voteCount: "23"),
                VoteOption(id: "3", title: "IoT", voteCount: "18"),
                VoteOption(id: "4", title: "게임 개발", voteCount: "34")
            ],
            startDate: Date(timeIntervalSinceNow: -86400),
            endDate: Date(timeIntervalSinceNow: 86400 * 7),
            allowMultipleChoices: false,
            isAnonymous: false,
            userVotedOptionIds: ["1"]
        ),
        isSubmitting: false,
        container: .init(),
        onVote: { _ in },
        onUpdateVote: { _ in }
    )
    .padding()
}

#Preview("투표 종료", traits: .sizeThatFitsLayout) {
    NoticeVoteCard(
        vote: NoticeVote(
            id: "poll3",
            question: "다음 해커톤 주제로 어떤 것이 좋을까요?",
            options: [
                VoteOption(id: "1", title: "AI/머신러닝", voteCount: "45"),
                VoteOption(id: "2", title: "블록체인", voteCount: "23"),
                VoteOption(id: "3", title: "IoT", voteCount: "18"),
                VoteOption(id: "4", title: "게임 개발", voteCount: "34")
            ],
            startDate: Date(timeIntervalSinceNow: -86400 * 10),
            endDate: Date(timeIntervalSinceNow: -86400),
            allowMultipleChoices: false,
            isAnonymous: true,
            userVotedOptionIds: ["1"]
        ),
        isSubmitting: false,
        container: .init(),
        onVote: { _ in },
        onUpdateVote: { _ in }
    )
    .padding()
}

#Preview("복수선택/익명", traits: .sizeThatFitsLayout) {
    NoticeVoteCard(
        vote: NoticeVote(
            id: "poll4",
            question: "참여하고 싶은 스터디를 모두 선택해주세요",
            options: [
                VoteOption(id: "1", title: "알고리즘", voteCount: "12"),
                VoteOption(id: "2", title: "CS 스터디", voteCount: "25"),
                VoteOption(id: "3", title: "디자인 패턴", voteCount: "8"),
                VoteOption(id: "4", title: "영어 회화", voteCount: "15")
            ],
            startDate: Date(timeIntervalSinceNow: -86400),
            endDate: Date(timeIntervalSinceNow: 86400 * 7),
            allowMultipleChoices: true,
            isAnonymous: true,
            userVotedOptionIds: []
        ),
        isSubmitting: false,
        container: .init(),
        onVote: { _ in },
        onUpdateVote: { _ in }
    )
    .padding()
}

#Preview("복수선택/실명 - 투표완료", traits: .sizeThatFitsLayout) {
    NoticeVoteCard(
        vote: NoticeVote(
            id: "poll5",
            question: "참여하고 싶은 스터디를 모두 선택해주세요",
            options: [
                VoteOption(id: "1", title: "알고리즘", voteCount: "12"),
                VoteOption(id: "2", title: "CS 스터디", voteCount: "25"),
                VoteOption(id: "3", title: "디자인 패턴", voteCount: "8"),
                VoteOption(id: "4", title: "영어 회화", voteCount: "15")
            ],
            startDate: Date(timeIntervalSinceNow: -86400),
            endDate: Date(timeIntervalSinceNow: 86400 * 7),
            allowMultipleChoices: true,
            isAnonymous: false,
            userVotedOptionIds: ["1", "2"]
        ),
        isSubmitting: false,
        container: .init(),
        onVote: { _ in },
        onUpdateVote: { _ in }
    )
    .padding()
}
#endif
