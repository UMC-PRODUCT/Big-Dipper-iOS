//
//  ChallengerAttendanceView.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/15/26.
//

import SwiftUI

/// 챌린저(일반 참여자)의 출석 체크 화면
///
/// 지도와 출석 버튼을 표시하며, 지오펜싱 상태에 따라 버튼 활성화를 제어합니다.
struct ChallengerAttendanceView: View, Equatable {
    @State private var mapViewModel: BaseMapViewModel
    @Bindable private var attendanceViewModel: ChallengerAttendanceViewModel
    @Namespace private var attendanceNamespace
    @State private var showReasonSheet: Bool = false
    @State private var isMapReady: Bool = false

    private let userId: UserID
    private let container: DIContainer
    private let errorHandler: ErrorHandler
    private let session: Session

    init(
        container: DIContainer,
        errorHandler: ErrorHandler,
        mapViewModel: BaseMapViewModel,
        attendanceViewModel: ChallengerAttendanceViewModel,
        userId: UserID,
        session: Session
    ) {
        self.container = container
        self.errorHandler = errorHandler
        self.session = session
        self._mapViewModel = .init(wrappedValue: mapViewModel)
        self.attendanceViewModel = attendanceViewModel
        self.userId = userId
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.userId == rhs.userId
    }

    private enum Constants {
        static let bottomPadding: CGFloat = 16
        static let mapProgressRadius: Edge.Corner.Style = 24
        static let attendanceActionId = "attendance-action"
        static let mapLoadDelay: Duration = .milliseconds(100)
        static let mapPlaceholderHeight: CGFloat = 200
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            if isMapReady {
                ActivityCompactMapView(
                    mapViewModel: mapViewModel,
                    info: session.info
                )
            } else {
                mapPlaceholder
            }
            attendanceActionView
            if attendanceViewModel.shouldShowReasonButton(for: session) {
                lateReasonButton
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: session.attendanceStatus)
        .animation(.easeInOut(duration: 0.2), value: isMapReady)
        .task {
            try? await Task.sleep(for: Constants.mapLoadDelay)
            isMapReady = true
        }
    }

    // MARK: - View Component

    /// Map 로딩 플레이스홀더
    private var mapPlaceholder: some View {
        ConcentricRectangle(corners: Constants.mapProgressRadius, isUniform: true)
            .fill(Color.grey100)
            .frame(height: Constants.mapPlaceholderHeight)
            .overlay {
                ProgressView()
                    .tint(.grey400)
            }
    }

    /// 출석 상태에 따른 액션 뷰 (버튼 또는 승인 대기 카드)
    @ViewBuilder
    private var attendanceActionView: some View {
        GlassEffectContainer {
            switch session.attendanceStatus {
            case .pendingApproval:
                // 승인 대기 카드 (버튼에서 모핑 전환)
                ChallengerPendingApprovalView()
                    .glassEffect(
                        .regular,
                        in: .rect(corners: .concentric(minimum: DefaultConstant.concentricRadius), isUniform: true))
                    .glassEffectID(
                        Constants.attendanceActionId, in: attendanceNamespace)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))

            case .beforeAttendance:
                // 출석 버튼
                attendanceButton
                    .glassEffectID(
                        Constants.attendanceActionId, in: attendanceNamespace)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))

            case .present, .late, .absent:
                // 확정 상태 - 버튼 비활성화
                attendanceButton
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .scale(scale: 0.95).combined(with: .opacity)
                    ))
            }
        }
    }

    private var attendanceButton: some View {
        MainButton(attendanceViewModel.buttonStyle(for: session)) {
            triggerHaptic()
            Task {
                guard let sheetId = attendanceViewModel
                    .sheetId(for: session.info.sessionId)
                else {
                    #if DEBUG
                    print("[Attendance] sheetId not found for sessionId: \(session.info.sessionId.value)")
                    print("[Attendance] availableSchedules: \(attendanceViewModel.availableSchedules)")
                    #endif
                    return
                }
                await attendanceViewModel.attendanceBtnTapped(
                    userId: userId,
                    session: session,
                    sheetId: sheetId
                )
                triggerSuccessHaptic()
            }
        }
        .buttonStyle(.glassProminent)
        .disabled(
            !attendanceViewModel.isAttendanceAvailable(for: session)
        )
    }

    private var lateReasonButton: some View {
        Button {
            showReasonSheet = true
        } label: {
            Text("위치 인증이 안 되나요? 사유 제출하기")
                .appFont(.caption1, color: .gray)
                .underline()
        }
        .buttonStyle(.plain)
        .disabled(
            !attendanceViewModel.isAttendanceAvailable(for: session)
            && !attendanceViewModel.isReasonSubmittable(for: session)
        )
        .sheet(isPresented: $showReasonSheet) {
            ChallengerAttendanceReasonSheet { reason in
                guard let sheetId = attendanceViewModel.sheetId(for: session.info.sessionId) else {
                    #if DEBUG
                    print("[Attendance] sheetId not found for reason submit")
                    #endif
                    return
                }
                await attendanceViewModel.submitAttendanceReason(
                    userId: userId,
                    session: session,
                    reason: reason,
                    sheetId: sheetId
                )
            }
        }
    }

    // MARK: - Haptic Feedback

    private func triggerHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    private func triggerSuccessHaptic() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#if DEBUG
// MARK: - Previews

private struct ChallengerAttendanceScenarioPreview: View {
    @State private var attendanceViewModel: ChallengerAttendanceViewModel
    @State private var mapViewModel: BaseMapViewModel

    private let session: Session
    private let subtitle: String

    init(
        title: String,
        subtitle: String,
        timeWindow: AttendanceTimeWindow,
        isInsideGeofence: Bool = true,
        isLocationAuthorized: Bool = true,
        session: Session? = nil
    ) {
        let previewSession = session ?? Self.makeSession(title: title)
        let mockUseCase = MockChallengerAttendanceUseCase()
        mockUseCase.mockTimeWindow = timeWindow
        mockUseCase.mockIsInsideGeofence = isInsideGeofence
        mockUseCase.mockIsLocationAuthorized = isLocationAuthorized
        mockUseCase.responseDelay = 0

        _attendanceViewModel = State(initialValue: ChallengerAttendanceViewModel(
            container: AttendancePreviewData.container,
            errorHandler: AttendancePreviewData.errorHandler,
            challengeAttendanceUseCase: mockUseCase
        ))
        _mapViewModel = State(initialValue: BaseMapViewModel(
            container: AttendancePreviewData.container,
            info: previewSession.info,
            errorHandler: AttendancePreviewData.errorHandler
        ))

        self.session = previewSession
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(subtitle)
                .appFont(.footnote, color: .grey600)

            ChallengerAttendanceView(
                container: AttendancePreviewData.container,
                errorHandler: AttendancePreviewData.errorHandler,
                mapViewModel: mapViewModel,
                attendanceViewModel: attendanceViewModel,
                userId: AttendancePreviewData.userId,
                session: session
            )
        }
        .padding()
        .background(Color.grey100)
    }

    private static func makeSession(title: String) -> Session {
        Session(
            info: SessionInfo(
                sessionId: SessionID(value: "preview_\(title)"),
                icon: .Activity.profile,
                title: title,
                week: 8,
                startTime: .now,
                endTime: .now.addingTimeInterval(7200),
                location: AttendancePreviewData.hansungCoordinate
            ),
            initialAttendance: nil
        )
    }
}

#Preview("정시 출석 가능") {
    ChallengerAttendanceScenarioPreview(
        title: "정시 출석 가능 세션",
        subtitle: "GPS 출석 버튼 활성화, 사유 제출 버튼도 활성화",
        timeWindow: .onTime
    )
}

#Preview("출석 전 사유 제출") {
    ChallengerAttendanceScenarioPreview(
        title: "출석 전 사유 제출 세션",
        subtitle: "아직 출석 시간 전이어도 사유 제출 버튼은 활성화",
        timeWindow: .tooEarly
    )
}

#Preview("지각 사유 제출") {
    ChallengerAttendanceScenarioPreview(
        title: "지각 사유 제출 세션",
        subtitle: "지각 시간대에서는 사유 제출 시 late reason 경로 사용",
        timeWindow: .lateWindow
    )
}

#Preview("마감 후 불참 사유") {
    ChallengerAttendanceScenarioPreview(
        title: "불참 사유 제출 세션",
        subtitle: "출석 마감 후에는 사유 제출 버튼이 숨김 처리됨",
        timeWindow: .expired
    )
}

#Preview("승인 대기 상태") {
    ChallengerAttendanceScenarioPreview(
        title: "승인 대기 세션",
        subtitle: "이미 사유 제출 완료된 상태라 버튼 대신 승인 대기 카드 표시",
        timeWindow: .lateWindow,
        session: AttendancePreviewData.pendingApprovalSession
    )
}
#endif
