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

    // MARK: - Init

    init(destination: ActivityDestination) {
        self.destination = destination
    }

    // MARK: - Body

    var body: some View {
        switch destination {
        case .studyScheduleRegistration(let studyName, _):
            // 화면(`StudyScheduleRegistrationView`)은 ViewModel 만 이식된 상태다.
            // 경로는 먼저 열어 두고, 화면 이식 시 이 분기만 실제 뷰로 교체한다.
            // TODO: #1014 StudyScheduleRegistrationView 이식 후 화면 연결 - [26.07.30] 이재원
            unsupportedScreen(
                title: "일정 등록 준비 중",
                message: "\(studyName)의 일정 등록 화면은 곧 연결됩니다."
            )

        case .attendanceDetail(let scheduleId):
            OperatorAttendanceDetailRoute(scheduleId: scheduleId)
        }
    }

    // MARK: - Function

    private func unsupportedScreen(title: String, message: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "hammer")
        } description: {
            Text(message)
        }
    }
}

// MARK: - Operator Attendance Detail

/// 운영진 출석 상세 화면의 조립 지점.
///
/// 목적지는 `scheduleId` 라는 값만 들고 오므로, 화면이 필요로 하는 ViewModel 은 여기서
/// DI 로 만든다. 탭 재진입마다 새로 만들지 않도록 첫 등장 때 한 번만 생성한다.
private struct OperatorAttendanceDetailRoute: View {

    // MARK: - Property

    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler

    @State private var viewModel: OperatorAttendanceViewModel?

    private let scheduleId: String

    // MARK: - Init

    init(scheduleId: String) {
        self.scheduleId = scheduleId
    }

    // MARK: - Body

    var body: some View {
        Group {
            if let viewModel {
                OperatorAttendanceDetailView(viewModel: viewModel, scheduleId: scheduleId)
            } else {
                ProgressView()
            }
        }
        .task {
            guard viewModel == nil else { return }
            viewModel = OperatorAttendanceViewModel(
                errorHandler: errorHandler,
                useCase: di.resolve(OperatorAttendanceUseCaseProtocol.self)
            )
        }
    }
}
