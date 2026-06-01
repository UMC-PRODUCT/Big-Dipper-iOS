//
//  NoticeReadStatusSheet.swift
//  NoticeData
//
//  Created by 이예지 on 6/1/26.
//

import SwiftUI
import UMCFoundation
import CoreDI
import CoreDesignSystem
import CoreUIComponents
import NoticeDomain

/// 공지 열람 현황 시트
///
/// 확인/미확인 사용자 목록을 세그먼트로 구분하고, 전체/지부/학교별 필터를 제공합니다.
public struct NoticeReadStatusSheet: View {
    
    // MARK: - Property
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: NoticeDetailViewModel
    @State public var rotationTrigger = 0
    
    // MARK: - Constant
    fileprivate enum Constants {
        static let listRowPadding: EdgeInsets = .init(top: 5, leading: .zero, bottom: 5, trailing: .zero)
        static let alarmPadding: EdgeInsets = .init(top: 10, leading: 14, bottom: 10, trailing: 14)
        static let capsulePadding: EdgeInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12)
    }
    
    // MARK: - Body
    public var body: some View {
        NavigationStack {
            Group {
                switch viewModel.readStatusState {
                case .idle, .loading:
                    loadingSection
                case .loaded(_):
                    userListSection
                case .failed(let error):
                    failedSection(error: error)
                }
            }
            .navigation(naviTitle: .noticeReadStatus, displayMode: .inline)
            .toolbar {
                ToolBarCollection.CancelBtn(action: {})
                
                if isLoadedState {
                    ToolBarCollection.ReadStatusFilter(
                        items: Array(ReadStatusFilterType.allCases),
                        selection: $viewModel.selectedFilter,
                        itemLabel: { $0.rawValue },
                        itemIcon: { $0.iconName }
                    )
                }
            }
            .safeAreaBar(edge: .top) {
                if isLoadedState {
                    segmentedSection
                        .padding(.bottom, DefaultSpacing.spacing8)
                }

            }
            .safeAreaBar(edge: .bottom, alignment: .trailing) {
                if isLoadedState {
                    GlassEffectContainer {
                        if viewModel.selectedReadTab == .unconfirmed {
                            reAlarmSection
                                .padding(.top, DefaultSpacing.spacing8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Private Property

    /// 열람 현황이 정상 로드된 상태인지 여부
    private var isLoadedState: Bool {
        viewModel.readStatusState.value != nil
    }

    /// 로딩 상태 섹션
    private var loadingSection: some View {
        VStack {
            Spacer()
            Progress(message: "공지 미확인 및 확인 리스트를 가져오는 중입니다")
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// 실패 상태 섹션
    private func failedSection(error: AppError) -> some View {
        RetryContentUnavailableView(
            title: "열람 현황을 불러오지 못했습니다.",
            systemImage: "exclamationmark.triangle",
            description: error.userMessage,
            isRetrying: viewModel.isRetryingReadStatus,
            minRetryButtonWidth: 64
        ) {
            await viewModel.retryFetchReadStatus()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    /// 상단 세그먼트(미확인/확인)
    private var segmentedSection: some View {
        Picker("", selection: $viewModel.selectedReadTab) {
            Text("미확인 \(viewModel.unconfirmedCount)")
                .tag(ReadStatusTab.unconfirmed)
            
            Text("확인 \(viewModel.confirmedCount)")
                .tag(ReadStatusTab.confirmed)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }
    
    // MARK: - User List Section

    /// 필터(전체/지부/학교)에 따라 유저 리스트를 분기 렌더링합니다.
    private var userListSection: some View {
        List {
            switch viewModel.selectedFilter {
            case .all:
                allUsersView
            case .branch:
                groupedView(groupedData: viewModel.groupedUsersByBranch)
            case .school:
                groupedView(groupedData: viewModel.groupedUsersBySchool)
            }

            if viewModel.isLoadingMoreReadStatus {
                HStack {
                    Spacer()
                    Progress(size: .small)
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(Constants.listRowPadding)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .contentMargins(.horizontal, DefaultConstant.defaultSafeHorizon, for: .scrollContent)
    }
    
    /// 전체 보기
    private var allUsersView: some View {
        ForEach(viewModel.filteredReadStatusUsers) { user in
            userRow(user)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(Constants.listRowPadding)
        }
    }
    
    /// 공통 그룹화 뷰 (지부별/학교별)
    private func groupedView(groupedData: [String: [ReadStatusUser]]) -> some View {
        ForEach(Array(groupedData.keys.sorted()), id: \.self) { key in
            Section {
                ForEach(groupedData[key] ?? []) { user in
                    userRow(user)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(Constants.listRowPadding)
                }
            } header: {
                Text(key)
                    .appFont(.callout, weight: .semibold, color: .black)
            }
        }
        .listSectionSpacing(DefaultSpacing.spacing8)
    }

    /// 유저 행(미확인 탭에서는 개별 재알림 스와이프 액션 제공)
    @ViewBuilder
    private func userRow(_ user: ReadStatusUser) -> some View {
        NoticeReadStatusItem(model: user.toItemModel())
            .task {
                await viewModel.loadMoreReadStatusIfNeeded(currentItem: user)
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if viewModel.selectedReadTab == .unconfirmed {
                    Button {
                        sendSingleReminder(to: user)
                    } label: {
                        Label("재알림", systemImage: "arrow.trianglehead.clockwise")
                    }
                    .tint(.green)
                }
            }
    }
    
    /// 하단 재알림 버튼 (미확인 탭에서만 표시)
    private var reAlarmSection: some View {
        Button(action: {
            rotationTrigger += 1

            Task {
                await viewModel.sendReminderToAllUnreadUsers()
            }
        }) {
            Label {
                Text("재알림 보내기")
            } icon: {
                Image(systemName: "arrow.trianglehead.clockwise")
                    .symbolEffect(.rotate, value: rotationTrigger)
                    .fontWeight(.bold)
            }
            .appFont(.body, weight: .medium, color: .white)
            .padding(Constants.alarmPadding)
            .background {
                RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                    .fill(Color.indigo400)
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }

    // MARK: - Private Function

    /// 특정 유저 1명에게 재알림 전송
    private func sendSingleReminder(to user: ReadStatusUser) {
        Task {
            await viewModel.sendReminder(targetIds: [user.id])
        }
    }
}
