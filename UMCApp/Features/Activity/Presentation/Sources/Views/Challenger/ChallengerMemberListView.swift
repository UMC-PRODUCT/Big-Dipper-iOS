//
//  ChallengerMemberListView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreDI
import CoreDomain
import CoreUIComponents
import SwiftUI
import UMCFoundation

/// 챌린저 모드의 구성원 목록 화면
///
/// 파트별로 그룹핑된 동아리 구성원을 무한 스크롤로 표시하고, 검색과 멤버 상세 시트를
/// 제공합니다. 화면 소유의 `NavigationStack` 없이 콘텐츠만 구성하며, 상위(Activity 루트)의
/// 네비게이션 컨텍스트 안에서 사용됩니다.
struct ChallengerMemberListView: View {

    // MARK: - Property

    @State private var viewModel: MemberListViewModel

    // MARK: - Constants

    private enum Constants {
        static let loadingOverlayRadius: CGFloat = 12
    }

    // MARK: - Init

    /// - Parameters:
    ///   - container: UseCase·세션을 resolve 할 DI 컨테이너
    ///   - errorHandler: 흐름 중단형 전역 에러 처리기
    ///   - viewModel: 프리뷰/테스트용 주입 지점 (기본값: container 로 생성)
    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        viewModel: MemberListViewModel? = nil
    ) {
        _viewModel = State(
            initialValue: viewModel ?? MemberListViewModel(
                fetchMembersUseCase: container.resolve(FetchMembersUseCaseProtocol.self),
                errorHandler: errorHandler,
                userSessionManager: container.resolve(UserSessionManager.self)
            )
        )
    }

    // MARK: - Body

    var body: some View {
        Group {
            switch viewModel.membersState {
            case .idle, .loading:
                loadingView
            case .loaded:
                memberListContent
            case .failed(let error):
                RetryContentUnavailableView(
                    title: "불러오지 못했어요",
                    systemImage: "exclamationmark.triangle",
                    description: error.userMessage,
                    isRetrying: false
                ) {
                    await viewModel.fetchMembers()
                }
            }
        }
        .task {
            await viewModel.fetchMembers()
        }
        .searchable(text: $viewModel.searchText)
        .searchToolbarBehavior(.minimize)
        .overlay {
            if viewModel.isLoadingMemberDetail {
                ProgressView()
                    .controlSize(.regular)
                    .padding()
                    .background(
                        .ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: Constants.loadingOverlayRadius)
                    )
            }
        }
        .sheet(item: $viewModel.selectedMember) { member in
            ChallengerMemberDetailSheetView(member: member)
        }
    }

    // MARK: - SubView

    private var loadingView: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            ProgressView()

            Text("챌린저 목록 불러오는 중...")
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var memberListContent: some View {
        Group {
            if viewModel.groupedMembers.isEmpty && viewModel.searchText.isEmpty {
                emptyMemberView
            } else if viewModel.isSearchResultEmpty {
                searchEmptyView
            } else {
                memberList
            }
        }
    }

    private var memberList: some View {
        List {
            ForEach(viewModel.groupedMembers, id: \.part) { group in
                Section {
                    ForEach(group.members) { item in
                        Button {
                            Task {
                                await viewModel.openChallengerMemberDetail(item)
                            }
                        } label: {
                            CoreMemberManagementRow(memberManagementItem: item)
                        }
                        // 상세 조회가 진행 중이면 다른 행 탭을 막는다. 가드가 없으면 서로
                        // 다른 멤버의 조회 Task 가 동시에 떠서 늦게 끝난 쪽이
                        // `selectedMember` 를 덮어써 엉뚱한 멤버의 시트가 열린다.
                        .disabled(viewModel.isLoadingMemberDetail)
                        .onAppear {
                            if item.id == group.members.last?.id,
                               group.part == viewModel.groupedMembers.last?.part {
                                Task { await viewModel.fetchNextPage() }
                            }
                        }
                    }
                } header: {
                    Text(group.part.name)
                        .appFont(.title3, weight: .semibold, color: .black)
                }
            }

            if viewModel.isLoadingNextPage {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowSeparator(.hidden)
            }
        }
    }

    private var searchEmptyView: some View {
        ContentUnavailableView {
            Label("검색 결과가 없습니다.", systemImage: "magnifyingglass")
        } description: {
            Text("'\(viewModel.searchText)'에 대한 결과가 없습니다")
        }
    }

    private var emptyMemberView: some View {
        ContentUnavailableView {
            Label("구성원 관리", systemImage: "person.3")
        } description: {
            Text("구성원이 없습니다.")
        }
    }
}

// MARK: - Preview

#if DEBUG
/// 네트워크 없이 구성원 목록을 확인하기 위한 프리뷰 전용 UseCase (핵심규칙 #5)
private struct PreviewFetchMembersUseCase: FetchMembersUseCaseProtocol {
    func execute() async throws -> [MemberManagementItem] {
        previewMembers
    }

    func executePage(page: Int) async throws -> MemberPage {
        MemberPage(members: previewMembers, hasNext: false, currentPage: page)
    }

    func grantPoint(
        challengerId: String,
        pointType: ChallengerPointType,
        pointValue: Int,
        description: String
    ) async throws {}

    func deletePoint(challengerPointId: String) async throws {}

    func fetchPointHistory(
        challengerId: String
    ) async throws -> [OperatorMemberPenaltyHistory] {
        []
    }

    func fetchAllGenerations(memberId: String) async throws -> String {
        "9기"
    }

    func fetchGenerationPointSummaries(
        memberId: String
    ) async throws -> [GenerationPointSummary] {
        []
    }

    func fetchAttendanceRecords(
        memberId: String
    ) async throws -> [MemberAttendanceRecord] {
        []
    }

    private var previewMembers: [MemberManagementItem] {
        [
            MemberManagementItem(
                memberID: "1",
                challengerID: "10",
                profile: nil,
                name: "이예지",
                nickname: "소피",
                generation: "9기",
                school: "가천대학교",
                position: "Part Leader",
                part: .front(type: .ios),
                penalty: 0,
                badge: false,
                managementTeam: .schoolPartLeader,
                attendanceRecords: [],
                penaltyHistory: []
            ),
            MemberManagementItem(
                memberID: "2",
                challengerID: "11",
                profile: nil,
                name: "홍길동",
                nickname: "라이언",
                generation: "9기",
                school: "한성대학교",
                position: "Challenger",
                part: .front(type: .web),
                penalty: 1,
                badge: false,
                managementTeam: .challenger,
                attendanceRecords: [],
                penaltyHistory: []
            ),
        ]
    }
}

#Preview {
    let viewModel = MemberListViewModel(
        fetchMembersUseCase: PreviewFetchMembersUseCase(),
        errorHandler: ErrorHandler(),
        userSessionManager: UserSessionManager()
    )
    return NavigationStack {
        ChallengerMemberListView(
            container: DIContainer(),
            errorHandler: ErrorHandler(),
            viewModel: viewModel
        )
    }
}
#endif
