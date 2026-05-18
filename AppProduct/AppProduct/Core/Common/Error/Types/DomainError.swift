//
//  DomainError.swift
//  AppProduct
//
//  Created by jaewon Lee on 1/7/25.
//

import Foundation

/// 도메인(비즈니스 로직) 관련 에러.
///
/// UMC 앱의 비즈니스 규칙 위반 시 발생하는 에러입니다.
/// 일반적으로 **Loadable** 방식으로 처리합니다.
///
/// ## 처리 원칙
///
/// DomainError는 대부분 **화면을 유지**하면서 사용자에게 안내해야 합니다:
/// - 출석 범위 밖 → 위치 이동 유도
/// - 이미 제출됨 → 단순 안내
/// - 사유 입력 필요 → 입력 유도
///
/// ## Usage
///
/// **UseCase에서 throw:**
///
/// ```swift
/// func requestGPSAttendance() async throws -> Attendance {
///     guard locationManager.isInsideGeofence else {
///         throw DomainError.attendanceOutOfRange
///     }
///     // ...
/// }
/// ```
///
/// **ViewModel에서 catch:**
///
/// ```swift
/// do {
///     let result = try await useCase.requestGPSAttendance()
///     state = .loaded(result)
/// } catch let error as DomainError {
///     // Loadable로 인라인 표시
///     state = .failed(.domain(error))
/// }
/// ```
///
/// **View에서 인라인 표시:**
///
/// ```swift
/// if let error = viewModel.state.error {
///     Text(error.userMessage)
///         .font(.caption)
///         .foregroundStyle(.red)
/// }
/// ```
///
/// - Important: DomainError는 ErrorHandler가 아닌 Loadable로 처리하세요.
///   사용자가 화면에서 직접 문제를 해결할 수 있어야 합니다.
///
/// - SeeAlso: ``AppError``, ``Loadable``
enum DomainError: Error, LocalizedError, Equatable {
    // MARK: - 공지사항

    /// 공지사항을 찾을 수 없음
    case noticeNotFound

    /// 공지사항 수정 불가
    case cannotEditNotice

    // MARK: - 출석

    /// 출석 가능 범위 벗어남 (GPS)
    case attendanceOutOfRange

    /// 이미 출석 완료
    case attendanceAlreadySubmitted

    /// 출석 시간 만료
    case attendanceTimeExpired

    /// 출석 사유 입력 필요
    case attendanceReasonRequired

    // MARK: - 일정

    /// 출석 기록이 존재하여 일정을 삭제할 수 없음 (최고 관리자만 강제 삭제 가능)
    case scheduleHasAttendanceRecords

    /// 이미 시작된 일정은 수정할 수 없음 (SCHEDULE-0028)
    case scheduleAlreadyStarted

    // MARK: - 워크북/과제

    /// 제출 기한 초과
    case workbookDeadlinePassed

    /// 이미 제출됨
    case workbookAlreadySubmitted

    /// 미션을 찾을 수 없음
    case missionNotFound

    /// 미션 링크 입력 필요
    case missionLinkRequired

    // MARK: - 커리큘럼

    /// 현재 운영 중이 아닌 기수라 커리큘럼 조회 불가
    case curriculumUnavailableForGeneration

    /// 서버에 커리큘럼이 아직 등록되지 않음 (CURRICULUM-0001)
    case curriculumNotRegistered

    // MARK: - 커뮤니티

    /// 게시글을 찾을 수 없음
    case postNotFound

    /// 게시글 삭제 불가
    case cannotDeletePost

    // MARK: - 권한

    /// 권한 부족
    case insufficientPermission(required: String)

    // MARK: - 기타

    /// 커스텀 에러 메시지
    case custom(message: String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .noticeNotFound:
            return "공지사항을 찾을 수 없습니다."
        case .cannotEditNotice:
            return "공지사항을 수정할 수 없습니다."
        case .attendanceOutOfRange:
            return "출석 가능 범위를 벗어났습니다."
        case .attendanceAlreadySubmitted:
            return "이미 출석을 완료했습니다."
        case .attendanceTimeExpired:
            return "출석 시간이 지났습니다."
        case .attendanceReasonRequired:
            return "출석 사유를 입력해주세요."
        case .scheduleHasAttendanceRecords:
            return "출석 기록이 있는 일정은 삭제할 수 없습니다. 최고 관리자에게 강제 삭제를 요청하세요."
        case .scheduleAlreadyStarted:
            return "이미 시작된 일정은 수정할 수 없습니다."
        case .workbookDeadlinePassed:
            return "제출 기한이 지났습니다."
        case .workbookAlreadySubmitted:
            return "이미 제출한 워크북입니다."
        case .missionNotFound:
            return "미션을 찾을 수 없습니다."
        case .missionLinkRequired:
            return "링크를 입력해주세요."
        case .curriculumUnavailableForGeneration:
            return "현재 운영중인 기수가 아니어서 커리큘럼을 조회할 수 없습니다."
        case .curriculumNotRegistered:
            return "아직 커리큘럼이 등록되지 않았어요. 조금만 기다려주세요!"
        case .postNotFound:
            return "게시글을 찾을 수 없습니다."
        case .cannotDeletePost:
            return "게시글을 삭제할 수 없습니다."
        case .insufficientPermission(let required):
            return "\(required) 권한이 필요합니다."
        case .custom(let message):
            return message
        }
    }

    /// 사용자에게 표시할 메시지
    var userMessage: String {
        errorDescription ?? ""
    }
}
