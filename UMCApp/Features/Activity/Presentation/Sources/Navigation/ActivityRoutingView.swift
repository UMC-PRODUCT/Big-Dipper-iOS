//
//  ActivityRoutingView.swift
//  ActivityPresentation
//
//  Created by 이재원 on 7/30/26.
//

import SwiftUI

import ActivityDomain
import CoreDI
import UMCFoundation

/// ``ActivityDestination`` 을 실제 화면으로 바꾸는 라우팅 뷰.
///
/// Activity 탭 루트가 `.navigationDestination(for: ActivityDestination.self)` 에서 사용한다.
/// 라우팅을 App 이 아니라 이 모듈이 맡는 덕분에, 목적지 화면들을 `public` 으로 열지 않고도
/// 탭 스택에 실을 수 있다.
///
/// 상위가 탭별 `NavigationStack` 을 제공하므로 여기서 스택을 만들지 않는다.
struct ActivityRoutingView: View {

    // MARK: - Property

    private let destination: ActivityDestination

    /// 탭 루트가 소유한 출석 ViewModel. 목록을 거치지 않는 딥링크도 같은 인스턴스로 착지한다.
    private let attendanceViewModel: OperatorAttendanceViewModel

    // MARK: - Init

    init(
        destination: ActivityDestination,
        attendanceViewModel: OperatorAttendanceViewModel
    ) {
        self.destination = destination
        self.attendanceViewModel = attendanceViewModel
    }

    // MARK: - Body

    var body: some View {
        switch destination {
        case .studyScheduleRegistration(let studyName, let studyGroupId):
            StudyScheduleRegistrationRoute(
                studyName: studyName,
                studyGroupId: studyGroupId
            )

        case .attendanceDetail(let scheduleId):
            OperatorAttendanceDetailView(
                viewModel: attendanceViewModel,
                scheduleId: scheduleId
            )
        }
    }
}

// MARK: - Study Schedule Registration

/// 스터디 일정 등록 화면의 조립 지점.
///
/// 목적지는 스터디 이름과 그룹 식별자만 들고 오므로, 화면이 필요로 하는 ViewModel 은 여기서
/// DI 로 만든다. 탭 재진입마다 새로 만들지 않도록 첫 등장 때 한 번만 생성한다.
private struct StudyScheduleRegistrationRoute: View {

    // MARK: - Property

    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler

    @State private var viewModel: StudyScheduleRegistrationViewModel?

    private let studyName: String
    private let studyGroupId: String

    // MARK: - Init

    init(studyName: String, studyGroupId: String) {
        self.studyName = studyName
        self.studyGroupId = studyGroupId
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                StudyScheduleRegistrationView(viewModel: viewModel)
            } else {
                ProgressView()
            }
        }
        .task {
            guard viewModel == nil else { return }
            viewModel = StudyScheduleRegistrationViewModel(
                studyName: studyName,
                studyGroupId: studyGroupId,
                studyMembersUseCase: di.resolve(FetchStudyMembersUseCaseProtocol.self),
                studyRepository: di.resolve(StudyRepositoryProtocol.self),
                registerScheduleUseCase: di.resolve(RegisterStudyScheduleUseCaseProtocol.self),
                errorHandler: errorHandler
            )
        }
    }
}
