//
//  AttendanceDetailView.swift
//  AppProduct
//
//  Created by euijjang97 on 5/6/26.
//

import SwiftUI

/// 단일 일정 출석 현황 상세 화면 (Schedule V2 #658)
///
/// `GET /api/v2/schedules/{id}/attendance` 응답을 헤더 + 참여자 리스트로 표시합니다.
/// 진입 경로:
/// - 출석 현황 목록 (`AttendanceListView`) → 행 탭
/// - 일정 상세 화면 → "출석 현황" 버튼 (cross-tab 라우팅 정책 후속, AC-Q1)
struct AttendanceDetailView: View {

    // MARK: - Property

    @Environment(\.di) private var di
    @State private var viewModel: AttendanceDetailViewModel

    // MARK: - Init

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        scheduleId: Int
    ) {
        let useCase = container.resolve(ActivityUseCaseProviding.self)
            .operatorAttendanceUseCase
        _viewModel = State(initialValue: AttendanceDetailViewModel(
            container: container,
            errorHandler: errorHandler,
            useCase: useCase,
            scheduleId: scheduleId
        ))
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch viewModel.detailState {
            case .idle, .loading:
                loadingView
            case .loaded(let info):
                content(info: info)
            case .failed(let error):
                errorView(error: error)
            }
        }
        .navigationTitle("출석 현황")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if case .idle = viewModel.detailState {
                await viewModel.fetch()
            }
        }
    }

    // MARK: - View Components

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func errorView(error: AppError) -> some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            Spacer()
            Image(systemName: viewModel.isScheduleDeleted ? "trash.slash" : "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(viewModel.isScheduleDeleted ? "삭제된 일정입니다" : error.userMessage)
                .appFont(.subheadline, color: .grey600)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DefaultConstant.defaultSafeHorizon)

            if viewModel.isScheduleDeleted {
                Button("이전으로") {
                    di.resolve(PathStore.self).activityPath.removeLast()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("다시 시도") {
                    Task { await viewModel.fetch() }
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func content(info: ScheduleAttendanceInfo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing16) {
                headerCard(info: info)
                statsRow(info: info)
                filterChipRow
                participantList
            }
            .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
            .padding(.top, DefaultConstant.defaultSafeTop)
            .padding(.bottom, DefaultConstant.defaultSafeBottom)
        }
    }

    private func headerCard(info: ScheduleAttendanceInfo) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            Text(info.name)
                .appFont(.title3Emphasis, color: .grey700)
                .lineLimit(2)

            if !info.description.isEmpty {
                Text(info.description)
                    .appFont(.subheadline, color: .grey600)
            }

            HStack(spacing: DefaultSpacing.spacing8) {
                Image(systemName: "calendar")
                    .font(.system(size: 12))
                    .foregroundStyle(.grey500)
                Text(dateRangeText(info: info))
                    .appFont(.footnote, color: .grey500)
            }

            if let location = info.location {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 12))
                        .foregroundStyle(.grey500)
                    Text(location.locationName)
                        .appFont(.footnote, color: .grey500)
                }
            } else if info.isOnline {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Image(systemName: "video")
                        .font(.system(size: 12))
                        .foregroundStyle(.grey500)
                    Text("비대면")
                        .appFont(.footnote, color: .grey500)
                }
            }
        }
        .padding(DefaultSpacing.spacing16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    private func statsRow(info: ScheduleAttendanceInfo) -> some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            statBlock(label: "출석", value: "\(info.presentCount) / \(info.totalCount)")
            statBlock(label: "대기", value: "\(info.pendingCount)")
            statBlock(label: "출석률", value: rateText(info: info))
        }
    }

    private func statBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
            Text(label)
                .appFont(.caption1, color: .grey500)
            Text(value)
                .appFont(.calloutEmphasis, color: .grey700)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DefaultSpacing.spacing12)
        .glassEffect(
            .regular,
            in: ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    private var filterChipRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DefaultSpacing.spacing8) {
                ChipButton(
                    "전체",
                    isSelected: viewModel.selectedFilter == nil
                ) {
                    if let current = viewModel.selectedFilter {
                        viewModel.filterButtonTapped(current)
                    }
                }
                .buttonSize(.small)

                ForEach(viewModel.filterableStatuses, id: \.self) { status in
                    ChipButton(
                        status.displayText,
                        isSelected: viewModel.selectedFilter == status
                    ) {
                        viewModel.filterButtonTapped(status)
                    }
                    .buttonSize(.small)
                }
            }
        }
    }

    @ViewBuilder
    private var participantList: some View {
        let participants = viewModel.filteredParticipants
        if participants.isEmpty {
            VStack(spacing: DefaultSpacing.spacing12) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 28))
                    .foregroundStyle(.grey400)
                Text("표시할 참여자가 없습니다")
                    .appFont(.subheadline, color: .grey500)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DefaultSpacing.spacing24)
        } else {
            LazyVStack(spacing: DefaultSpacing.spacing8) {
                ForEach(participants) { participant in
                    ParticipantAttendanceRow(participant: participant)
                }
            }
        }
    }

    // MARK: - Helper

    private func dateRangeText(info: ScheduleAttendanceInfo) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.M.d (E) HH:mm"
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let start = formatter.string(from: info.startsAt)

        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "HH:mm"
        endFormatter.locale = Locale(identifier: "ko_KR")
        endFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        let end = endFormatter.string(from: info.endsAt)
        return "\(start) ~ \(end)"
    }

    private func rateText(info: ScheduleAttendanceInfo) -> String {
        guard info.totalCount > 0 else { return "—" }
        let percent = Int((info.attendanceRate * 100).rounded())
        return "\(percent)%"
    }
}

// MARK: - Row

private struct ParticipantAttendanceRow: View, Equatable {

    let participant: ParticipantAttendance

    static func == (lhs: ParticipantAttendanceRow, rhs: ParticipantAttendanceRow) -> Bool {
        lhs.participant.memberId == rhs.participant.memberId
            && lhs.participant.attendanceStatus == rhs.participant.attendanceStatus
            && lhs.participant.isLocationVerified == rhs.participant.isLocationVerified
            && lhs.participant.excuseReason == rhs.participant.excuseReason
    }

    var body: some View {
        HStack(spacing: DefaultSpacing.spacing12) {
            avatar

            VStack(alignment: .leading, spacing: DefaultSpacing.spacing4) {
                HStack(spacing: DefaultSpacing.spacing8) {
                    Text(participant.name)
                        .appFont(.calloutEmphasis, color: .grey700)
                        .lineLimit(1)
                    Text(participant.nickname)
                        .appFont(.footnote, color: .grey500)
                        .lineLimit(1)
                }
                HStack(spacing: DefaultSpacing.spacing8) {
                    Text(participant.schoolName)
                        .appFont(.caption1, color: .grey500)
                        .lineLimit(1)

                    if participant.isLocationVerified {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text("GPS 인증")
                                .appFont(.caption2, color: .green)
                        }
                        .foregroundStyle(.green)
                    }
                }

                if let reason = participant.excuseReason {
                    Text("사유: \(reason)")
                        .appFont(.caption1, color: .grey600)
                        .lineLimit(2)
                }
            }

            Spacer()

            AttendanceStatusBadge(status: participant.attendanceStatus)
        }
        .padding(DefaultSpacing.spacing12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(
            .regular,
            in: ConcentricRectangle(
                corners: .concentric(minimum: DefaultConstant.concentricRadius),
                isUniform: true
            )
        )
    }

    private var avatar: some View {
        RemoteImage(
            urlString: participant.profileImageUrl,
            size: CGSize(width: 40, height: 40),
            cornerRadius: 20
        )
    }
}
