//
//  AttendancePreviewData.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/15/26.
//

import Foundation
import SwiftUI
import SwiftData

/// 출석 관련 프리뷰에서 사용하는 더미 데이터 모음
struct AttendancePreviewData {

    #if DEBUG
    static let errorHandler = ErrorHandler()
    static let container: DIContainer = {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try! ModelContainer(
            for: GenerationMappingRecord.self, NoticeHistoryData.self,
            configurations: config
        )
        return DIContainer.configured(
            modelContext: modelContainer.mainContext
        )
    }()
    static let challengerAttendanceUseCase = ChallengerAttendanceUseCase(repository: MockAttendanceRepository())
    static let mockUseCase = MockChallengerAttendanceUseCase()
    static let mapViewModel: BaseMapViewModel = .init(container: container, info: sessionInfo, errorHandler: errorHandler)
    static let attendanceViewModel: ChallengerAttendanceViewModel = .init(
        container: container,
        errorHandler: errorHandler,
        challengeAttendanceUseCase: mockUseCase  // 시뮬레이터 테스트용 Mock 사용
    )
    #endif

    static let sessionId: SessionID = SessionID(value: "iOS_8")
    static let userId: UserID = UserID(value: "River_")

    /// 한성대학교 좌표
    static let hansungCoordinate: Coordinate = .init(latitude: 37.582967, longitude: 127.010527)
    /// 공덕 창업허브 좌표
    static let gongdeokCoordinate: Coordinate = .init(latitude: 37.5445, longitude: 126.9519)

    // Legacy compatibility
    static let coordinate: Coordinate = hansungCoordinate

    static let attendance: Attendance = .init(
        sessionId: sessionId,
        userId: userId,
        type: .gps,
        status: .beforeAttendance,
        locationVerification: .init(
            isVerified: true,
            coordinate: hansungCoordinate,
            address: .init(
                fullAddress: "한성대학교", city: "서울시", district: "성북구"),
            verifiedAt: .now),
        reason: nil)

    static let sessionInfo: SessionInfo = .init(
        sessionId: SessionID(value: "iOS_8"),
        icon: .Activity.profile,
        title: "좋은 컴포넌트 설계란 무엇일까",
        week: 8,
        startTime: Date.now,
        endTime: Date.now + 7200,
        location: hansungCoordinate)

    static let session: Session = .init(info: sessionInfo, initialAttendance: attendance)

    // MARK: - State-specific Sessions

    /// 출석 전 상태 세션 (버튼 활성화)
    static var beforeAttendanceSession: Session {
        let info = SessionInfo(
            sessionId: SessionID(value: "iOS_before"),
            icon: .Activity.profile,
            title: "좋은 컴포넌트 설계란 무엇일까",
            week: 8,
            startTime: Date.now,
            endTime: Date.now + 7200,
            location: hansungCoordinate
        )
        return Session(info: info, initialAttendance: nil)
    }

    /// 승인 대기 상태 세션
    static var pendingApprovalSession: Session {
        let info = SessionInfo(
            sessionId: SessionID(value: "iOS_pending_approval"),
            icon: .Activity.profile,
            title: "UIKit을 SwiftUI에 녹이는 방법 – UIViewControllerRepresentable",
            week: 9,
            startTime: Date.now.addingTimeInterval(-3600),
            endTime: Date.now + 3600,
            location: hansungCoordinate
        )
        let session = Session(
            info: info,
            initialAttendance: .init(
                sessionId: info.sessionId,
                userId: userId,
                type: .gps,
                status: .beforeAttendance,
                locationVerification: .init(
                    isVerified: true,
                    coordinate: hansungCoordinate,
                    address: .init(fullAddress: "한성대학교", city: "서울시", district: "성북구"),
                    verifiedAt: .now
                ),
                reason: nil
            )
        )
        // 제출 완료 상태로 설정하면 pendingApproval 상태가 됨
        session.markSubmitted()
        return session
    }

    // MARK: - Multiple Sessions Mock

    /// 나의 출석 현황 (1~7주차 + 연합 OT + 연합 네트워킹 데이)
    static let sessions: [Session] = [
        // 연합 OT (출석)
        .init(
            info: .init(
                sessionId: SessionID(value: "union_ot"),
                icon: .Activity.profile,
                title: "연합 OT",
                week: 0,
                startTime: Date.now.addingTimeInterval(-86400 * 56),
                endTime: Date.now.addingTimeInterval(-86400 * 56 + 7200),
                location: gongdeokCoordinate
            ),
            initialAttendance: .init(
                sessionId: SessionID(value: "union_ot"),
                userId: userId,
                type: .gps,
                status: .present,
                locationVerification: nil,
                reason: nil
            )
        ),
        // 1주차: SwiftUI 화면 구성 및 상태 관리 (출석)
        .init(
            info: .init(
                sessionId: SessionID(value: "iOS_1"),
                icon: .Activity.profile,
                title: "SwiftUI 화면 구성 및 상태 관리",
                week: 1,
                startTime: Date.now.addingTimeInterval(-86400 * 49),
                endTime: Date.now.addingTimeInterval(-86400 * 49 + 7200),
                location: hansungCoordinate
            ),
            initialAttendance: .init(
                sessionId: SessionID(value: "iOS_1"),
                userId: userId,
                type: .gps,
                status: .present,
                locationVerification: nil,
                reason: nil
            )
        ),
        // 2주차: SwiftUI 데이터 바인딩 및 MVVM 패턴 (출석)
        .init(
            info: .init(
                sessionId: SessionID(value: "iOS_2"),
                icon: .Activity.profile,
                title: "SwiftUI 데이터 바인딩 및 MVVM 패턴",
                week: 2,
                startTime: Date.now.addingTimeInterval(-86400 * 42),
                endTime: Date.now.addingTimeInterval(-86400 * 42 + 7200),
                location: hansungCoordinate
            ),
            initialAttendance: .init(
                sessionId: SessionID(value: "iOS_2"),
                userId: userId,
                type: .gps,
                status: .present,
                locationVerification: nil,
                reason: nil
            )
        ),
        // 3주차: SwiftUI 리스트와 스크롤뷰, 그리고 네비게이션까지! (출석)
        .init(
            info: .init(
                sessionId: SessionID(value: "iOS_3"),
                icon: .Activity.profile,
                title: "SwiftUI 리스트와 스크롤뷰, 그리고 네비게이션까지!",
                week: 3,
                startTime: Date.now.addingTimeInterval(-86400 * 35),
                endTime: Date.now.addingTimeInterval(-86400 * 35 + 7200),
                location: hansungCoordinate
            ),
            initialAttendance: .init(
                sessionId: SessionID(value: "iOS_3"),
                userId: userId,
                type: .gps,
                status: .present,
                locationVerification: nil,
                reason: nil
            )
        ),
        // 4주차: 순간 반응하는 앱 만들기 – Swift 비동기와 Combine (결석)
        .init(
            info: .init(
                sessionId: SessionID(value: "iOS_4"),
                icon: .Activity.profile,
                title: "순간 반응하는 앱 만들기 – Swift 비동기와 Combine",
                week: 4,
                startTime: Date.now.addingTimeInterval(-86400 * 28),
                endTime: Date.now.addingTimeInterval(-86400 * 28 + 7200),
                location: hansungCoordinate
            ),
            initialAttendance: .init(
                sessionId: SessionID(value: "iOS_4"),
                userId: userId,
                type: .gps,
                status: .absent,
                locationVerification: nil,
                reason: nil
            )
        ),
        // 연합 네트워킹 데이 (지각)
        .init(
            info: .init(
                sessionId: SessionID(value: "union_networking"),
                icon: .Activity.profile,
                title: "연합 네트워킹 데이",
                week: 0,
                startTime: Date.now.addingTimeInterval(-86400 * 25),
                endTime: Date.now.addingTimeInterval(-86400 * 25 + 7200),
                location: gongdeokCoordinate
            ),
            initialAttendance: .init(
                sessionId: SessionID(value: "union_networking"),
                userId: userId,
                type: .gps,
                status: .late,
                locationVerification: nil,
                reason: nil
            )
        ),
        // 5주차: API 없이도 앱이 동작하게 – 모델 설계와 JSON 파싱 (출석)
        .init(
            info: .init(
                sessionId: SessionID(value: "iOS_5"),
                icon: .Activity.profile,
                title: "API 없이도 앱이 동작하게 – 모델 설계와 JSON 파싱",
                week: 5,
                startTime: Date.now.addingTimeInterval(-86400 * 21),
                endTime: Date.now.addingTimeInterval(-86400 * 21 + 7200),
                location: hansungCoordinate
            ),
            initialAttendance: .init(
                sessionId: SessionID(value: "iOS_5"),
                userId: userId,
                type: .gps,
                status: .present,
                locationVerification: nil,
                reason: nil
            )
        ),
        // 6주차: 진짜 서버랑 대화하기 – Alamofire API 연동 1 (출석)
        .init(
            info: .init(
                sessionId: SessionID(value: "iOS_6"),
                icon: .Activity.profile,
                title: "진짜 서버랑 대화하기 – Alamofire API 연동 1",
                week: 6,
                startTime: Date.now.addingTimeInterval(-86400 * 14),
                endTime: Date.now.addingTimeInterval(-86400 * 14 + 7200),
                location: hansungCoordinate
            ),
            initialAttendance: .init(
                sessionId: SessionID(value: "iOS_6"),
                userId: userId,
                type: .gps,
                status: .present,
                locationVerification: nil,
                reason: nil
            )
        ),
        // 7주차: Moya로 깔끔하게 통신하기 - API 연동 실전 2 (출석)
        .init(
            info: .init(
                sessionId: SessionID(value: "iOS_7"),
                icon: .Activity.profile,
                title: "Moya로 깔끔하게 통신하기 - API 연동 실전 2",
                week: 7,
                startTime: Date.now.addingTimeInterval(-86400 * 7),
                endTime: Date.now.addingTimeInterval(-86400 * 7 + 7200),
                location: hansungCoordinate
            ),
            initialAttendance: .init(
                sessionId: SessionID(value: "iOS_7"),
                userId: userId,
                type: .gps,
                status: .present,
                locationVerification: nil,
                reason: nil
            )
        ),
        // MARK: 출석 가능한 세션
        // PM DAY (공덕 창업허브) - 출석 전 (onTime: 시작시간 ±10분 내)
        .init(
            info: .init(
                sessionId: SessionID(value: "pm_day"),
                icon: .Activity.profile,
                title: "PM DAY",
                week: 0,
                startTime: Date.now.addingTimeInterval(-300),  // 5분 전 시작 → onTime 상태
                endTime: Date.now.addingTimeInterval(7200),
                location: gongdeokCoordinate
            ),
            initialAttendance: nil
        ),
        // 스터디 8주차 (한성대학교) - 출석 전 (tooEarly: 시작시간 10분 전 이후 대기)
        .init(
            info: .init(
                sessionId: SessionID(value: "iOS_8"),
                icon: .Activity.profile,
                title: "좋은 컴포넌트 설계란 무엇일까",
                week: 8,
                startTime: Date.now.addingTimeInterval(1800),  // 30분 후 시작
                endTime: Date.now.addingTimeInterval(9000),
                location: hansungCoordinate
            ),
            initialAttendance: nil
        )
    ]

    /// 모든 상태를 포함하는 세션 목록 (테스트용)
    static var allStatusSessions: [Session] {
        var list = sessions
        list.append(pendingApprovalSession)
        return list
    }

    /// 출석 가능한 세션 (PM DAY + 스터디 8주차)
    static var multipleAvailableSessions: [Session] {
        [
            // PM DAY (공덕 창업허브)
            .init(
                info: .init(
                    sessionId: SessionID(value: "pm_day"),
                    icon: .Activity.profile,
                    title: "PM DAY",
                    week: 0,
                    startTime: Date.now,
                    endTime: Date.now + 7200,
                    location: gongdeokCoordinate
                ),
                initialAttendance: nil
            ),
            // 스터디 8주차 (한성대학교)
            .init(
                info: .init(
                    sessionId: SessionID(value: "iOS_8"),
                    icon: .Activity.profile,
                    title: "좋은 컴포넌트 설계란 무엇일까",
                    week: 8,
                    startTime: Date.now + 3600,
                    endTime: Date.now + 3600 + 7200,
                    location: hansungCoordinate
                ),
                initialAttendance: nil
            ),
            // 승인 대기 세션
            pendingApprovalSession,
            // 완료된 세션 (나의 출석 현황에 표시)
            .init(
                info: .init(
                    sessionId: SessionID(value: "iOS_7"),
                    icon: .Activity.profile,
                    title: "Moya로 깔끔하게 통신하기 - API 연동 실전 2",
                    week: 7,
                    startTime: Date.now.addingTimeInterval(-86400 * 7),
                    endTime: Date.now.addingTimeInterval(-86400 * 7 + 7200),
                    location: hansungCoordinate
                ),
                initialAttendance: .init(
                    sessionId: SessionID(value: "iOS_7"),
                    userId: userId,
                    type: .gps,
                    status: .present,
                    locationVerification: nil,
                    reason: nil
                )
            )
        ]
    }

    // MARK: - Simulator Test Sessions

    /// 시뮬레이터 테스트용 세션 목록 (상태 변경 가능)
    static var testSessions: [Session] {
        [
            // PM DAY (공덕 창업허브)
            .init(
                info: .init(
                    sessionId: SessionID(value: "test_pm_day"),
                    icon: .Activity.profile,
                    title: "PM DAY",
                    week: 0,
                    startTime: Date.now,
                    endTime: Date.now + 7200,
                    location: gongdeokCoordinate
                ),
                initialAttendance: nil
            ),
            // 스터디 8주차 (한성대학교)
            .init(
                info: .init(
                    sessionId: SessionID(value: "test_iOS_8"),
                    icon: .Activity.profile,
                    title: "좋은 컴포넌트 설계란 무엇일까",
                    week: 8,
                    startTime: Date.now + 3600,
                    endTime: Date.now + 3600 + 7200,
                    location: hansungCoordinate
                ),
                initialAttendance: nil
            ),
            // 완료된 세션들
            .init(
                info: .init(
                    sessionId: SessionID(value: "test_iOS_6"),
                    icon: .Activity.profile,
                    title: "진짜 서버랑 대화하기 – Alamofire API 연동 1",
                    week: 6,
                    startTime: Date.now.addingTimeInterval(-86400 * 14),
                    endTime: Date.now.addingTimeInterval(-86400 * 14 + 7200),
                    location: hansungCoordinate
                ),
                initialAttendance: .init(
                    sessionId: SessionID(value: "test_iOS_6"),
                    userId: userId,
                    type: .gps,
                    status: .present,
                    locationVerification: nil,
                    reason: nil
                )
            ),
            .init(
                info: .init(
                    sessionId: SessionID(value: "test_iOS_7"),
                    icon: .Activity.profile,
                    title: "Moya로 깔끔하게 통신하기 - API 연동 실전 2",
                    week: 7,
                    startTime: Date.now.addingTimeInterval(-86400 * 7),
                    endTime: Date.now.addingTimeInterval(-86400 * 7 + 7200),
                    location: hansungCoordinate
                ),
                initialAttendance: .init(
                    sessionId: SessionID(value: "test_iOS_7"),
                    userId: userId,
                    type: .gps,
                    status: .late,
                    locationVerification: nil,
                    reason: nil
                )
            )
        ]
    }
}

// MARK: - Attendance Status Preview

#if DEBUG
/// 출석 상태별 배지 디자인을 확인하는 프리뷰 뷰
struct AttendanceStatusPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("출석 상태별 테스트")
                    .appFont(.title2Emphasis, color: .grey900)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ForEach(AttendanceStatus.allCases, id: \.self) { status in
                    HStack {
                        Text(status.displayText)
                            .appFont(.body, color: status.fontColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(status.backgroundColor, in: Capsule())

                        Spacer()

                        Text(status.rawValue)
                            .appFont(.caption1, color: .grey600)
                    }
                    .padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding()
        }
        .background(Color.grey100)
    }
}

/// 출석 화면 진입 테스트용 프리뷰 뷰
struct AttendanceTestView: View {
    @Binding var show: Bool

    var body: some View {
        VStack(spacing: 20) {
            Button("출석 화면 열기") {
                show.toggle()
            }
            .buttonStyle(.borderedProminent)

            Divider()
        }
        .task {
            LocationManager.shared.requestAuthorization()
        }
    }
}

#Preview("Attendance Status Badges") {
    AttendanceStatusPreview()
}

#Preview("Pending Approval View") {
    ZStack {
        Color.grey100.ignoresSafeArea()
        ChallengerPendingApprovalView()
            .padding()
    }
}
#endif
