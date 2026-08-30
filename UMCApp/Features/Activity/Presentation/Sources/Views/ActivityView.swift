//
//  ActivityView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/3/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreDI
import CoreDomain
import CoreRouting
import CoreUIComponents
import HomeDomain
import SwiftUI
import UMCFoundation

/// Activity 탭 루트 화면
///
/// 로그인 역할이 결정하는 모드(``CoreDomain/ActivityMode``)와 사용자가 고른 섹션
/// (``ActivitySection``)의 조합으로 자식 화면을 고른다. 섹션 전환은 상단 타이틀 메뉴에서 하고,
/// 모드가 바뀌면 보고 있던 자리에 대응하는 섹션으로 옮겨 같은 성격의 화면을 유지한다.
///
/// - Important: 자체 `NavigationStack` 을 만들지 않는다. 탭별 스택은 상위 탭 셸이 소유하고,
///   자식 화면들도 같은 규약으로 이식돼 있어 여기서 스택을 만들면 중첩된다.
struct ActivityView: View {

    // MARK: - Property

    /// 탭 스택의 공유 경로. 자식 화면이 요청한 push 를 이 저장소로 넘긴다.
    @Environment(PathStore.self) private var pathStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var viewModel: ActivityViewModel
    @State private var selectedSection: ActivitySection?

    /// 출석 푸시가 지목한 일정 식별자. 여기서는 섹션만 옮기고, 비우는 책임은 세션을 실제로
    /// 펼치는 말단(``ChallengerAttendanceSessionView``)에 있다.
    @Binding private var focusedScheduleId: String?

    /// 출석 목록·상세가 공유하는 단일 ViewModel.
    ///
    /// 상세의 승인/반려가 목록 배지에 즉시 반영되려면 두 화면이 같은 인스턴스를 봐야 한다.
    /// 딥링크(홈 → 일정 상세 → 출석 현황)는 목록을 거치지 않고 상세로 착지하므로, 소유자는
    /// 목록이 아니라 두 진입점의 공통 조상인 탭 루트(이 화면)다.
    @State private var attendanceViewModel: OperatorAttendanceViewModel

    /// 다른 탭이 올린 진입 요청. 소비하면 비운다(``consumePendingEntry()``).
    @Binding private var pendingEntry: ActivityEntry?

    private let container: DIContainer
    private let errorHandler: ErrorHandler
    private let userSession: UserSessionManager

    // MARK: - Init

    /// - Parameters:
    ///   - container: 자식 화면이 UseCase·세션을 resolve 할 DI 컨테이너
    ///   - errorHandler: 흐름 중단형 전역 에러 처리기
    ///   - pendingEntry: 다른 탭에서 넘어온 진입 요청. 처리 후 `nil` 로 비운다.
    ///   - focusedScheduleId: 딥링크가 지목한 일정. 출석 섹션으로 옮겨 그 세션을 펼친다.
    ///   - viewModel: 프리뷰/테스트용 주입 지점 (기본값: container 로 생성)
    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        pendingEntry: Binding<ActivityEntry?>,
        focusedScheduleId: Binding<String?> = .constant(nil),
        viewModel: ActivityViewModel? = nil
    ) {
        self.container = container
        self.errorHandler = errorHandler
        _pendingEntry = pendingEntry
        _focusedScheduleId = focusedScheduleId
        self.userSession = container.resolve(UserSessionManager.self)
        _viewModel = State(
            initialValue: viewModel ?? ActivityViewModel(
                challengerAttendanceUseCase: container.resolve(
                    ChallengerAttendanceUseCaseProtocol.self
                ),
                fetchUserIdUseCase: container.resolve(FetchUserIdUseCaseProtocol.self),
                classifyScheduleUseCase: container.resolve(ClassifyScheduleUseCaseProtocol.self)
            )
        )
        _attendanceViewModel = State(
            initialValue: OperatorAttendanceViewModel(
                errorHandler: errorHandler,
                useCase: container.resolve(OperatorAttendanceUseCaseProtocol.self)
            )
        )
    }

    // MARK: - Computed Property

    private var mode: ActivityMode {
        userSession.currentActivityMode
    }

    /// 현재 모드에서 고를 수 있는 섹션 목록
    private var availableSections: [ActivitySection] {
        ActivitySection.sections(for: mode)
    }

    /// 사용자가 고른 섹션 (고르기 전이면 모드의 기본 섹션)
    ///
    /// 밖에서 들어온 요청(``pendingEntry``)이 있으면 그것을 먼저 본다. 소비는 `.task` 가
    /// 하지만, 첫 렌더부터 요청한 섹션이 나와야 기본 섹션인 출석 화면이 한 프레임 스쳐
    /// 지나가지(그리고 세션 로딩을 헛되이 시작하지) 않는다.
    private var currentSection: ActivitySection {
        if let pendingEntry {
            return pendingEntry.section(in: mode)
        }
        return selectedSection ?? ActivitySection.defaultSection(for: mode)
    }

    private var sectionBinding: Binding<ActivitySection> {
        Binding(
            get: { currentSection },
            set: { selectedSection = $0 }
        )
    }

    // MARK: - Body

    var body: some View {
        sectionContent
            .navigationTitle(currentSection.title)
            .navigationBarTitleDisplayMode(.inline)
            .umcDefaultBackground()
            .navigationDestination(
                for: ActivityDestination.self
            ) { [attendanceViewModel] destination in
                ActivityRoutingView(
                    destination: destination,
                    attendanceViewModel: attendanceViewModel
                )
            }
            .toolbar {
                ToolBarCollection.ToolBarCenterMenu(
                    items: availableSections,
                    selection: sectionBinding,
                    itemLabel: \.title,
                    itemIcon: \.icon
                )
            }
            .task {
                await viewModel.load()
            }
            .task(id: pendingEntry) {
                consumePendingEntry()
            }
            .onChange(of: mode) { oldMode, newMode in
                let previous = selectedSection ?? ActivitySection.defaultSection(for: oldMode)
                selectedSection = previous.mapped(to: newMode)
            }
            .onChange(of: focusedScheduleId, initial: true) { _, scheduleId in
                guard scheduleId != nil else { return }
                // 현재 모드로 번역해서 옮긴다 — 운영진 모드에서 `.attendanceCheck` 를 그대로
                // 넣으면 `sectionContent` 의 `default` 로 떨어져 빈 화면이 된다. 운영진은
                // 출석 관리 화면까지만 착지하고 세션 펼침은 적용되지 않는다(푸시를 받는 쪽은
                // 챌린저 본인이라 정상 경로가 아니다).
                selectedSection = ActivitySection.attendanceCheck.mapped(to: mode)
            }
    }

    // MARK: - Function

    /// 다른 탭이 올린 진입 요청을 소비해 그 섹션으로 옮긴다.
    ///
    /// 요청이 도착하는 시점에 이 화면은 이미 살아 있을 수도(그 탭을 본 적 있음), 아직
    /// 만들어지지 않았을 수도(한 번도 안 봄) 있다. `.task(id:)` 는 등장 시점과 값 변경
    /// 시점 양쪽에서 돌아 두 경우를 하나로 덮는다 — `.onChange` 만 쓰면 후자에서 요청이
    /// 등록 전에 지나가 버린다.
    ///
    /// 비우지 않으면 ``currentSection`` 이 계속 요청을 우선해 섹션 메뉴가 먹지 않는다.
    private func consumePendingEntry() {
        guard let pendingEntry else { return }

        selectedSection = pendingEntry.section(in: mode)
        self.pendingEntry = nil
    }

    // MARK: - View Component

    /// 모드×섹션 조합에 해당하는 자식 화면
    ///
    /// 두 축을 함께 스위치해 "운영진 모드인데 챌린저 섹션" 같은 성립하지 않는 조합이
    /// 남지 않게 한다. 섹션 목록 자체가 모드로 걸러지므로 `default` 는 도달하지 않지만,
    /// 열거형이 늘어날 때 컴파일을 막지 않도록 빈 화면으로 닫아 둔다.
    @ViewBuilder
    private var sectionContent: some View {
        switch (mode, currentSection) {
        case (.challenger, .attendanceCheck):
            attendanceContent

        case (.challenger, .studyActivity):
            ChallengerStudyView(
                viewModel: ChallengerStudyViewModel(
                    fetchCurriculumOverviewUseCase: container.resolve(
                        FetchCurriculumOverviewUseCaseProtocol.self
                    )
                )
            )

        case (.challenger, .members):
            ChallengerMemberListView(container: container, errorHandler: errorHandler)

        case (.admin, .attendanceManage):
            OperatorAttendanceView(
                viewModel: attendanceViewModel,
                onScheduleSelected: { scheduleId in
                    pathStore.push(
                        ActivityDestination.attendanceDetail(scheduleId: scheduleId),
                        on: .activity
                    )
                }
            )

        case (.admin, .studyManage):
            OperatorStudyManagementView(
                viewModel: OperatorStudyManagementViewModel(
                    errorHandler: errorHandler,
                    useCase: container.resolve(OperatorStudyManagementUseCaseProtocol.self)
                ),
                userSession: userSession,
                onRegisterSchedule: { group in
                    // 식별자는 서버 응답 그대로 `String` 이라 변환 단계가 없다.
                    pathStore.push(
                        ActivityDestination.studyScheduleRegistration(
                            studyName: group.name,
                            studyGroupId: group.serverID
                        ),
                        on: .activity
                    )
                }
            )

        case (.admin, .memberManage):
            OperatorMemberManagementView(container: container, errorHandler: errorHandler)

        default:
            EmptyView()
        }
    }

    /// 출석 체크 섹션 — 세션 목록 상태에 따라 분기
    @ViewBuilder
    private var attendanceContent: some View {
        switch viewModel.sessionsState {
        case .idle, .loading:
            loadingView

        case .loaded(let sessions):
            // 출석 주체를 모른 채로는 출석 기록을 남길 수 없다. 레거시는 빈 식별자로
            // 폴백했지만, 그러면 로그인 세션이 끊긴 상태가 조용히 흡수돼 잘못된 주체로
            // 기록이 남는다. 식별자가 없으면 재조회를 안내한다.
            if let userId = viewModel.userId {
                ChallengerAttendanceSessionView(
                    container: container,
                    errorHandler: errorHandler,
                    sessions: sessions,
                    schedules: viewModel.schedules,
                    userId: userId,
                    focusedScheduleId: $focusedScheduleId
                )
                .task {
                    await viewModel.startPollingIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase == .active else { return }
                    Task { await viewModel.refreshSessions() }
                }
            } else {
                missingUserIdView
            }

        case .failed(let error):
            RetryContentUnavailableView(
                title: "불러오지 못했어요",
                systemImage: "exclamationmark.triangle",
                description: error.userMessage,
                isRetrying: false
            ) {
                await viewModel.fetchSessions()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            ProgressView()

            Text("세션 불러오는 중...")
                .appFont(.subheadline, color: .grey500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var missingUserIdView: some View {
        RetryContentUnavailableView(
            title: "사용자 정보를 확인하지 못했어요",
            systemImage: "person.crop.circle.badge.exclamationmark",
            description: "출석을 기록하려면 로그인 정보가 필요해요.\n다시 시도해도 같으면 재로그인해 주세요.",
            isRetrying: false
        ) {
            await viewModel.fetchUserId()
        }
    }

}
