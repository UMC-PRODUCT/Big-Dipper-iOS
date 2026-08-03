//
//  ChallengerAttendanceView.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/2/26.
//

import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import SwiftUI
import UIKit
import UMCFoundation

/// 챌린저(일반 참여자)의 출석 체크 화면
///
/// 지도와 출석 버튼을 표시하며, 지오펜싱 상태에 따라 버튼 활성화를 제어합니다.
struct ChallengerAttendanceView: View, Equatable {

    // MARK: - Property

    private let mapViewModel: BaseMapViewModel?
    private let attendanceViewModel: ChallengerAttendanceViewModel
    private let userId: UserID
    private let session: Session

    @Namespace private var attendanceNamespace
    @State private var showReasonSheet: Bool = false
    @State private var showPolicyPopover: Bool = false
    @State private var isMapReady: Bool = false

    // MARK: - Init

    /// - Parameter mapViewModel: 지도 상태 모델. 서버 일정 ID가 아직 해석되지 않아
    ///   지오펜스를 등록할 수 없는 세션은 `nil` 이 들어오며, 지도 대신 플레이스홀더를
    ///   표시합니다. (임의의 대체 ID를 넘기면 지오펜스가 항상 어긋납니다)
    init(
        mapViewModel: BaseMapViewModel?,
        attendanceViewModel: ChallengerAttendanceViewModel,
        userId: UserID,
        session: Session
    ) {
        self.mapViewModel = mapViewModel
        self.attendanceViewModel = attendanceViewModel
        self.userId = userId
        self.session = session
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.userId == rhs.userId
            && lhs.session.id == rhs.session.id
            && lhs.session.attendanceStatus == rhs.session.attendanceStatus
            // 일정 ID 가 해석되면 지도 모델이 nil → 인스턴스로 바뀐다. 이 축을 빼면
            // 상위가 .equatable() 로 감싸는 탓에 플레이스홀더가 그대로 굳는다.
            && lhs.mapViewModel === rhs.mapViewModel
    }

    // MARK: - Constants

    fileprivate enum Constants {
        static let mapCornerRadius: Edge.Corner.Style = 24
        static let mapLoadDelay: Duration = .milliseconds(100)
        static let mapPlaceholderHeight: CGFloat = 200
        static let attendanceActionId = "attendance-action"
        static let statusAnimationResponse: Double = 0.4
        static let statusAnimationDamping: Double = 0.75
        static let mapReadyAnimationDuration: Double = 0.2
        static let actionTransitionScale: CGFloat = 0.95
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: DefaultSpacing.spacing16) {
            ZStack(alignment: .topTrailing) {
                mapSection

                scheduleInfoButton
                    .padding(DefaultSpacing.spacing12)
            }

            attendanceGuidanceLine
            attendanceActionView

            if attendanceViewModel.shouldShowReasonButton(for: session) {
                lateReasonButton
            }
        }
        .animation(
            .spring(
                response: Constants.statusAnimationResponse,
                dampingFraction: Constants.statusAnimationDamping
            ),
            value: session.attendanceStatus
        )
        .animation(.easeInOut(duration: Constants.mapReadyAnimationDuration), value: isMapReady)
        .task {
            // 카드 펼침 애니메이션과 지도 초기화가 겹치면 프레임이 튀어 한 틱 뒤로 미룬다.
            try? await Task.sleep(for: Constants.mapLoadDelay)
            isMapReady = true
        }
        .sheet(isPresented: $showReasonSheet) {
            ChallengerAttendanceReasonSheet { reason in
                // 진입점(사유 버튼)이 scheduleId 없이는 눌리지 않으므로 여기 도달하면
                // 항상 값이 있다. 시트가 열린 사이 값이 사라지는 경우만 방어하며, 사용자가
                // 작성한 사유가 조용히 버려지지 않도록 게이트는 버튼 쪽에 둔다.
                guard let scheduleId else { return }

                await attendanceViewModel.submitAttendanceReason(
                    userId: userId,
                    session: session,
                    reason: reason,
                    scheduleId: scheduleId
                )
            }
        }
    }

    // MARK: - Function

    /// 출석·사유 제출에 필요한 서버 일정 ID (`nil` = 아직 해석 전)
    ///
    /// 이 값이 없으면 어떤 제출도 서버에 도달할 수 없으므로, 액션 버튼을 모두 비활성화해
    /// 사용자가 입력을 낭비하지 않게 합니다.
    private var scheduleId: String? {
        attendanceViewModel.scheduleId(for: session.info.sessionId)
    }

    // MARK: - View Components

    @ViewBuilder
    private var mapSection: some View {
        if let mapViewModel {
            if isMapReady {
                ActivityCompactMapView(mapViewModel: mapViewModel)
            } else {
                mapPlaceholder { ProgressView().tint(.grey400) }
            }
        } else {
            // 일정 ID 가 없으면 지오펜스를 등록할 수 없다. 곧 로드될 것처럼 보이는 스피너
            // 대신 정적 안내를 띄운다 — 실제로는 대기해도 지도가 나타나지 않는다.
            mapPlaceholder {
                VStack(spacing: DefaultSpacing.spacing8) {
                    Image(systemName: "mappin.slash")
                        .font(.title2)
                        .foregroundStyle(Color.grey400)
                    Text("위치 정보를 아직 불러올 수 없어요")
                        .appFont(.footnote, color: .grey500)
                }
            }
        }
    }

    /// Map 자리를 차지하는 회색 플레이스홀더
    private func mapPlaceholder(
        @ViewBuilder content: () -> some View
    ) -> some View {
        ConcentricRectangle(corners: Constants.mapCornerRadius, isUniform: true)
            .fill(Color.grey100)
            .frame(height: Constants.mapPlaceholderHeight)
            .overlay { content() }
    }

    /// 출석 정책 팝오버를 여는 정보 버튼 (지도 우상단 오버레이)
    private var scheduleInfoButton: some View {
        Button {
            showPolicyPopover = true
        } label: {
            Image(systemName: "info.circle")
                .font(.title3)
                .foregroundStyle(Color.grey700)
                .padding(DefaultSpacing.spacing8)
        }
        .glassEffect(.regular.interactive(), in: .circle)
        .accessibilityLabel("출석 정책 보기")
        .popover(isPresented: $showPolicyPopover) {
            policyPopoverContent
                .presentationCompactAdaptation(.popover)
        }
    }

    /// 출석 정책 3개 시각 팝오버 콘텐츠
    ///
    /// 시트 대신 ⓘ 버튼에 앵커된 말풍선으로 정책만 간편하게 확인합니다.
    /// 첫 마운트 직후 정책이 비어 있으면 배경 갱신으로 채웁니다.
    @ViewBuilder
    private var policyPopoverContent: some View {
        if let policy = attendanceViewModel.attendancePolicy(for: session.info.sessionId) {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                Text("출석 정책")
                    .appFont(.callout, weight: .semibold, color: .grey900)

                // 세 시각 모두 체크인 시작을 기준일로 삼아, 자정을 넘긴 마감만 날짜를 덧붙인다.
                let anchor = policy.checkInStartAt
                policyRow(role: .checkIn, date: anchor, anchor: anchor)
                policyRow(role: .onTime, date: policy.onTimeEndAt, anchor: anchor)
                policyRow(role: .late, date: policy.lateEndAt, anchor: anchor)
            }
            .padding(DefaultSpacing.spacing16)
        } else {
            // 갱신을 요청하되 "불러오는 중" 이라고 단정하지 않는다. 일정 조회가 결선되기
            // 전까지 refreshAvailableSchedules() 는 no-op 이라 기다려도 채워지지 않는다.
            Text("등록된 출석 정책이 없어요")
                .appFont(.footnote, color: .grey500)
                .padding(DefaultSpacing.spacing16)
                .task {
                    await attendanceViewModel.refreshAvailableSchedules()
                }
        }
    }

    /// 정책 행 (아이콘 + 라벨 + 시각)
    private func policyRow(
        role: AttendancePolicyRole,
        date: Date,
        anchor: Date
    ) -> some View {
        let timeText = date.attendancePolicyText(anchoredAt: anchor)

        return HStack(spacing: DefaultSpacing.spacing8) {
            Image(systemName: role.iconName)
                .font(.caption)
                .foregroundStyle(role.tintColor)
            Text(role.label)
                .appFont(.footnote, color: .grey600)
            Spacer(minLength: DefaultSpacing.spacing16)
            Text(timeText)
                .appFont(.footnote, weight: .semibold, color: .grey700)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(role.label): \(timeText)")
    }

    /// 출석 버튼 위 시간대별 동적 안내 라인
    ///
    /// 분 단위로 갱신되며, 출석 전 상태에서만 표시됩니다.
    /// 정책 시각이 로드되면 마감 시각과 남은 시간을 함께 보여줍니다.
    private var attendanceGuidanceLine: some View {
        TimelineView(.everyMinute) { context in
            if let guidance = attendanceViewModel.attendanceGuidanceText(
                for: session,
                at: context.date
            ) {
                let isLateWindow = attendanceViewModel.timeWindow(for: session) == .lateWindow

                HStack(spacing: DefaultSpacing.spacing4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text(guidance)
                }
                .appFont(.footnote, color: isLateWindow ? .orange : .grey600)
                .frame(maxWidth: .infinity)
            }
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
                        in: .rect(
                            corners: .concentric(minimum: DefaultConstant.concentricRadius),
                            isUniform: true
                        )
                    )
                    .glassEffectID(Constants.attendanceActionId, in: attendanceNamespace)
                    .transition(actionTransition)

            case .beforeAttendance:
                // 지각 시간대에는 사유 제출이 기본 액션으로 승격, 그 외에는 GPS 출석 버튼
                Group {
                    if attendanceViewModel.timeWindow(for: session) == .lateWindow {
                        lateReasonPrimaryButton
                    } else {
                        attendanceButton
                    }
                }
                .glassEffectID(Constants.attendanceActionId, in: attendanceNamespace)
                .transition(actionTransition)

            case .present, .late, .absent:
                // 확정 상태 - 버튼 비활성화
                attendanceButton
                    .transition(actionTransition)
            }
        }
    }

    private var actionTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: Constants.actionTransitionScale).combined(with: .opacity),
            removal: .scale(scale: Constants.actionTransitionScale).combined(with: .opacity)
        )
    }

    private var attendanceButton: some View {
        MainButton(attendanceViewModel.buttonTitle(for: session)) {
            triggerImpactHaptic()

            Task {
                guard let scheduleId else { return }

                await attendanceViewModel.attendanceButtonTapped(
                    userId: userId,
                    session: session,
                    scheduleId: scheduleId
                )
                triggerSuccessHaptic()
            }
        }
        .buttonStyle(.glassProminent)
        .disabled(!attendanceViewModel.isAttendanceAvailable(for: session) || scheduleId == nil)
    }

    /// 지각 시간대의 기본 액션 버튼 — 사유 제출 시트 열기
    ///
    /// 비활성 GPS 버튼 + 보조 링크의 중복 구조를 대체합니다.
    private var lateReasonPrimaryButton: some View {
        MainButton("지각 사유 제출하기") {
            triggerImpactHaptic()
            showReasonSheet = true
        }
        .buttonStyle(.glassProminent)
        .disabled(!canOpenReasonSheet)
    }

    /// 사유 제출 보조 링크 (정시/시작 전 시간대 전용)
    private var lateReasonButton: some View {
        Button {
            showReasonSheet = true
        } label: {
            Text("위치 인증이 안 되나요? 사유 제출하기")
                .appFont(.caption1, color: .grey500)
                .underline()
        }
        .buttonStyle(.plain)
        .disabled(!canOpenReasonSheet)
    }

    /// 사유 시트를 열어도 되는지 — 도메인 조건 + 제출 경로 확보 여부
    ///
    /// 일정 ID 가 없으면 사유를 받아도 서버로 보낼 수 없으므로 시트 자체를 막습니다.
    /// (열어두면 사용자가 작성·확인한 사유가 조용히 버려집니다)
    private var canOpenReasonSheet: Bool {
        attendanceViewModel.isReasonSubmittable(for: session) && scheduleId != nil
    }

    // MARK: - Haptic Feedback

    private func triggerImpactHaptic() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
    }

    private func triggerSuccessHaptic() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

#if DEBUG
// MARK: - Preview

#Preview("정시 출석 가능", traits: .sizeThatFitsLayout) {
    AttendancePreviewData.attendanceScenario(
        subtitle: "GPS 출석 버튼 활성화, 사유 제출 보조 링크도 노출",
        timeWindow: .onTime
    )
}

#Preview("지각 사유 제출", traits: .sizeThatFitsLayout) {
    AttendancePreviewData.attendanceScenario(
        subtitle: "지각 시간대에서는 사유 제출이 기본 버튼으로 승격",
        timeWindow: .lateWindow
    )
}

#Preview("승인 대기 상태", traits: .sizeThatFitsLayout) {
    AttendancePreviewData.attendanceScenario(
        subtitle: "사유 제출 완료 상태라 버튼 대신 승인 대기 카드 표시",
        timeWindow: .lateWindow,
        attendanceStatus: .pendingApproval
    )
}
#endif
