//
//  GuestMocks.swift
//  AppProduct
//

import CoreLocation
import Foundation

// MARK: - GuestTokenStore

/// 게스트 세션용 TokenStore
///
/// Keychain에 접근하지 않으며, 토큰은 항상 nil을 반환합니다.
actor GuestTokenStore: TokenStore {

    func getAccessToken() async -> String? { nil }

    func getRefreshToken() async -> String? { nil }

    func save(accessToken: String, refreshToken: String) async throws {}

    func clear() async throws {}
}

// MARK: - MockStorageRepository

/// 게스트 세션용 Storage Repository Mock
///
/// 파일 업로드 기능을 사용하지 않는 게스트 세션에서 의존성을 충족합니다.
final class MockStorageRepository: StorageRepositoryProtocol {

    func prepareUpload(
        fileName: String,
        contentType: String,
        fileSize: Int,
        category: StorageFileCategory
    ) async throws -> StoragePrepareUploadResponseDTO {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func uploadFile(
        to url: String,
        data: Data,
        method: String,
        headers: [String: String]?,
        contentType: String?
    ) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func confirmUpload(fileId: String) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }

    func deleteFile(fileId: String) async throws {
        throw DomainError.insufficientPermission(required: "인증")
    }
}

// MARK: - MockAuthorizationRepository

/// 게스트 세션용 Authorization Repository Mock
///
/// 모든 리소스에 대해 빈 권한 집합을 반환합니다.
final class MockAuthorizationRepository: AuthorizationRepositoryProtocol {

    func getResourcePermission(
        resourceType: AuthorizationResourceType,
        resourceId: Int
    ) async throws -> ResourcePermission {
        ResourcePermission(
            resourceType: resourceType,
            resourceId: resourceId,
            grantedPermissions: []
        )
    }
}

// MARK: - MockNoticeEditorTargetRepository

/// 게스트 세션용 NoticeEditorTarget Repository Mock
///
/// 공지 에디터의 타겟(지부/학교) 선택 시트에서 빈 목록을 반환합니다.
final class MockNoticeEditorTargetRepository: NoticeEditorTargetRepositoryProtocol {

    func fetchAllBranches() async throws -> [NoticeTargetOption] { [] }

    func fetchBranches(gisuId: Int) async throws -> [NoticeTargetOption] { [] }

    func fetchBranchName(chapterId: Int) async throws -> String { "" }

    func fetchAllSchools() async throws -> [NoticeTargetOption] { [] }

    func fetchSchools(gisuId: Int) async throws -> [NoticeTargetOption] { [] }

    func fetchSchools(inChapterId chapterId: Int, gisuId: Int) async throws -> [NoticeTargetOption] { [] }
}

// MARK: - MockTMapGeocodingRepository

/// 게스트 세션용 TMap 지오코딩 Repository Mock
///
/// 장소 선택 시 좌표 조회 없이 nil을 반환합니다.
final class MockTMapGeocodingRepository: TMapGeocodingRepositoryProtocol {

    func geocodeCoordinate(from address: String) async -> CLLocationCoordinate2D? {
        nil
    }
}

// MARK: - GuestChallengerAttendanceUseCase

/// 게스트 세션용 ChallengerAttendance UseCase
///
/// 위치 권한 체크 및 지오펜스 검증을 우회하여 Mock 성공을 반환합니다.
/// 실제 LocationManager.requestAuthorization() 호출은 ViewModel/View 레이어에서 그대로 진행됩니다.
final class GuestChallengerAttendanceUseCase: ChallengerAttendanceUseCaseProtocol {

    var isInsideGeofence: Bool { true }
    var isLocationAuthorized: Bool { true }

    func fetchAvailableSchedules() async throws -> [AvailableAttendanceSchedule] {
        [
            AvailableAttendanceSchedule(
                scheduleId: 1,
                scheduleName: "9기 OT",
                tags: ["SEMINAR", "ALL"],
                startTime: "10:00:00",
                endTime: "12:00:00",
                sheetId: 1,
                recordId: 1,
                status: .beforeAttendance,
                statusDisplay: "출석 전",
                locationVerified: true
            )
        ]
    }

    func fetchMyHistory() async throws -> [AttendanceHistoryItem] {
        [
            AttendanceHistoryItem(
                attendanceId: 1,
                scheduleId: 1,
                scheduleName: "9기 OT",
                tags: ["SEMINAR", "ALL"],
                scheduledDate: "2024-01-15",
                startTime: "14:30",
                endTime: "16:00",
                status: .present,
                statusDisplay: "출석"
            )
        ]
    }

    func requestGPSAttendance(
        sessionId: SessionID,
        userId: UserID,
        sheetId: Int
    ) async throws -> Attendance {
        Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .gps,
            status: .beforeAttendance,
            locationVerification: LocationVerification(
                isVerified: true,
                coordinate: Coordinate(latitude: 37.5, longitude: 127.0),
                address: .init(fullAddress: "서울특별시", city: "서울", district: ""),
                verifiedAt: .now
            ),
            reason: nil
        )
    }

    func submitLateReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        sheetId: Int
    ) async throws -> Attendance {
        Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .reason,
            status: .pendingApproval,
            locationVerification: nil,
            reason: reason
        )
    }

    func submitAbsentReason(
        sessionId: SessionID,
        userId: UserID,
        reason: String,
        sheetId: Int
    ) async throws -> Attendance {
        Attendance(
            sessionId: sessionId,
            userId: userId,
            type: .reason,
            status: .pendingApproval,
            locationVerification: nil,
            reason: reason
        )
    }

    func isWithinAttendanceTime(info: SessionInfo) -> AttendanceTimeWindow {
        .onTime
    }

    func getAddressToCurrentLocation() async throws -> String {
        "서울특별시 중구"
    }

    func stopGeofenceMonitoring() async {}
}
