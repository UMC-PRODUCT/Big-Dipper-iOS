//
//  AttendancePreviewSupport.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 8/2/26.
//

#if DEBUG
import ActivityDomain
import CoreDesignSystem
import CoreDI
import Foundation
import HomeDomain
import SwiftUI
import UMCFoundation

// MARK: - Preview UseCase

/// 프리뷰 전용 스텁 UseCase — 시간대·지오펜스 판정을 주입값으로 고정하고, 제출은 no-op.
final class PreviewChallengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol {

    let isInsideGeofence: Bool
    let isLocationAuthorized: Bool

    private let timeWindow: AttendanceTimeWindow

    init(
        timeWindow: AttendanceTimeWindow = .onTime,
        isInsideGeofence: Bool = true,
        isLocationAuthorized: Bool = true
    ) {
        self.timeWindow = timeWindow
        self.isInsideGeofence = isInsideGeofence
        self.isLocationAuthorized = isLocationAuthorized
    }

    func requestGPSAttendance(
        sessionId: SessionID,
        userId: UserID,
        scheduleId: String
    ) async throws -> Attendance {
        Attendance(sessionId: sessionId, userId: userId, type: .gps, status: .present)
    }

    func submitLateReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .reason,
            status: .pendingApproval,
            reason: reason
        )
    }

    func submitAbsentReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        scheduleId: String
    ) async throws -> Attendance {
        Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .reason,
            status: .pendingApproval,
            reason: reason
        )
    }

    func isWithinAttendanceTime(info: SessionInfo, now: Date) -> AttendanceTimeWindow {
        timeWindow
    }

    func getAddressToCurrentLocation() async throws -> Address {
        Address(fullAddress: "서울특별시 성북구 삼선교로16길 116", city: "서울특별시", district: "성북구")
    }

    func stopGeofenceMonitoring() async {}
}

// MARK: - Preview Data

/// 출석 화면 프리뷰용 고정 데이터·팩토리 모음
enum AttendancePreviewData {

    // MARK: - 고정값

    /// 한성대학교 좌표 — 지도 프리뷰의 앵커
    static let campusCoordinate = Coordinate(latitude: 37.582_2, longitude: 127.010_4)

    static let userId = UserID(value: "U-preview")

    /// 프리뷰 기준 시각 (2026-06-11 14:00 KST). 카드의 날짜/시간 표시를 결정론적으로 만든다.
    static let referenceDate = Date(timeIntervalSince1970: 1_781_154_000)

    /// 이력 카드의 정책 요약 표시용 — `referenceDate` 에 고정되어 렌더가 매번 같다.
    static let displayPolicy = ScheduleAttendancePolicy(
        checkInStartAt: referenceDate.addingTimeInterval(-10 * 60),
        onTimeEndAt: referenceDate.addingTimeInterval(10 * 60),
        lateEndAt: referenceDate.addingTimeInterval(60 * 60)
    )

    /// 요청한 시간대가 실제로 그 시간대로 렌더되도록 **현재 시각 기준**으로 만든 정책
    ///
    /// ViewModel 의 시간대 판정은 정책이 있으면 UseCase 폴백을 건너뛰므로, 고정 과거
    /// 시각으로 정책을 만들면 어떤 시나리오를 요청하든 전부 `.expired` 로 보입니다.
    static func policy(
        for window: AttendanceTimeWindow,
        now: Date = .now
    ) -> ScheduleAttendancePolicy {
        let minute: TimeInterval = 60
        switch window {
        case .tooEarly:
            return .init(
                checkInStartAt: now.addingTimeInterval(10 * minute),
                onTimeEndAt: now.addingTimeInterval(30 * minute),
                lateEndAt: now.addingTimeInterval(60 * minute)
            )
        case .onTime:
            return .init(
                checkInStartAt: now.addingTimeInterval(-10 * minute),
                onTimeEndAt: now.addingTimeInterval(10 * minute),
                lateEndAt: now.addingTimeInterval(60 * minute)
            )
        case .lateWindow:
            return .init(
                checkInStartAt: now.addingTimeInterval(-60 * minute),
                onTimeEndAt: now.addingTimeInterval(-10 * minute),
                lateEndAt: now.addingTimeInterval(30 * minute)
            )
        case .expired:
            return .init(
                checkInStartAt: now.addingTimeInterval(-180 * minute),
                onTimeEndAt: now.addingTimeInterval(-120 * minute),
                lateEndAt: now.addingTimeInterval(-60 * minute)
            )
        }
    }

    // MARK: - Session

    @MainActor
    static func session(
        id: String,
        title: String,
        week: Int,
        status: AttendanceStatus = .beforeAttendance
    ) -> Session {
        let info = SessionInfo(
            sessionId: SessionID(value: id),
            category: .study,
            iconName: ScheduleIconCategory.study.rawValue,
            title: title,
            week: week,
            startTime: referenceDate,
            endTime: referenceDate.addingTimeInterval(2 * 3_600),
            location: campusCoordinate
        )
        guard status != .beforeAttendance else {
            return Session(info: info, initialAttendance: nil)
        }
        return Session(
            info: info,
            initialAttendance: Attendance(
                sessionId: info.sessionId,
                userId: userId,
                type: .gps,
                status: status
            )
        )
    }

    /// 출석 가능 세션 + 확정 이력이 섞인 목록
    @MainActor
    static var mixedSessions: [Session] {
        [
            session(id: "S-1", title: "8주차 정기 세션", week: 8),
            session(id: "S-2", title: "7주차 정기 세션", week: 7, status: .present),
            session(id: "S-3", title: "6주차 데모데이", week: 6, status: .late),
        ]
    }

    /// 모두 출석이 확정되어 출석 가능 세션이 없는 목록
    @MainActor
    static var completedSessions: [Session] {
        [
            session(id: "S-2", title: "7주차 정기 세션", week: 7, status: .present),
            session(id: "S-3", title: "6주차 데모데이", week: 6, status: .absent),
        ]
    }

    /// 아직 아무도 출석하지 않아 이력이 비는 목록
    @MainActor
    static var upcomingSessions: [Session] {
        [session(id: "S-1", title: "8주차 정기 세션", week: 8)]
    }

    // MARK: - MyAttendanceItemModel

    /// 펼침 가능한(정책·장소를 가진) 출석 이력 항목
    static func myAttendanceItem(
        title: String = "8주차 정기 세션",
        status: MyAttendanceItemStatus = .present
    ) -> MyAttendanceItemModel {
        MyAttendanceItemModel(
            week: 8,
            title: title,
            startTime: referenceDate,
            endTime: referenceDate.addingTimeInterval(2 * 3_600),
            status: status,
            category: .study,
            attendancePolicy: displayPolicy,
            locationName: "공학관 6층 세미나실"
        )
    }

    static var myAttendanceItems: [MyAttendanceItemModel] {
        [
            myAttendanceItem(title: "8주차 정기 세션", status: .present),
            myAttendanceItem(title: "7주차 정기 세션", status: .late),
            myAttendanceItem(title: "6주차 데모데이", status: .absent),
        ]
    }

    // MARK: - ViewModel / Container

    /// - Parameter sessions: 이 세션들에 대응하는 일정 페이로드를 채운다.
    ///   일정이 없으면 화면이 출석·사유 버튼을 비활성화하므로 프리뷰가 비어 보인다.
    ///
    /// - Note: 일정 ID는 세션 ID와 같은 값이어야 한다. 화면이 쓰는 일정 ID·출석 정책은
    ///   모두 이 페이로드에서 `SessionID` 로 조회되므로, 다른 값을 넣으면 매칭에 실패한다.
    @MainActor
    static func viewModel(
        timeWindow: AttendanceTimeWindow = .onTime,
        sessions: [Session] = []
    ) -> ChallengerAttendanceViewModel {
        let viewModel = ChallengerAttendanceViewModel(
            errorHandler: ErrorHandler(),
            challengerAttendanceUseCase: PreviewChallengerAttendanceUseCase(
                timeWindow: timeWindow
            )
        )
        viewModel.seedSchedulesForPreview(
            sessions.map { schedule(for: $0, timeWindow: timeWindow) }
        )
        return viewModel
    }

    /// 세션 하나에 대응하는 프리뷰 일정 페이로드
    @MainActor
    private static func schedule(
        for session: Session,
        timeWindow: AttendanceTimeWindow
    ) -> ScheduleDetailData {
        let info = session.info
        return ScheduleDetailData(
            scheduleId: info.sessionId.value,
            name: info.title,
            description: "",
            tags: [],
            startsAt: info.startTime,
            endsAt: info.endTime,
            isParticipant: true,
            attendancePolicy: policy(for: timeWindow)
        )
    }

    /// 화면 init 의 `container:` 를 채우기 위한 스텁 컨테이너
    ///
    /// 프리뷰는 ViewModel 을 직접 주입하므로 이 등록이 실제로 resolve 되지는 않지만,
    /// 주입 없이 쓰는 호출부가 생겨도 크래시하지 않도록 등록해 둡니다.
    static var container: DIContainer {
        let container = DIContainer()
        container.register(ChallengerAttendanceUseCaseProtocol.self) {
            PreviewChallengerAttendanceUseCase()
        }
        return container
    }

    // MARK: - View Factory

    /// 출석 체크 상세 한 건을 시나리오 설명과 함께 감싼 프리뷰
    ///
    /// 지도 모델은 실제 위치 권한·지오펜스를 잡으므로 프리뷰에서는 `nil` 을 넘겨
    /// 플레이스홀더로 렌더한다. (일정 ID 자체는 주입되어 액션 버튼은 활성 상태다)
    @MainActor
    static func attendanceScenario(
        subtitle: String,
        timeWindow: AttendanceTimeWindow,
        attendanceStatus: AttendanceStatus = .beforeAttendance
    ) -> some View {
        let session = session(
            id: "S-preview",
            title: "8주차 정기 세션",
            week: 8,
            status: attendanceStatus
        )

        return VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            Text(subtitle)
                .appFont(.footnote, color: .grey600)

            ChallengerAttendanceView(
                mapViewModel: nil,
                attendanceViewModel: viewModel(timeWindow: timeWindow, sessions: [session]),
                userId: userId,
                session: session
            )
        }
        .padding()
        .background(Color.grey100)
    }

    /// 출석 진입 화면 전체 프리뷰
    @MainActor
    static func sessionScreen(sessions: [Session]) -> some View {
        ChallengerAttendanceSessionView(
            container: container,
            errorHandler: ErrorHandler(),
            sessions: sessions,
            userId: userId,
            viewModel: viewModel(sessions: sessions)
        )
    }
}
#endif
