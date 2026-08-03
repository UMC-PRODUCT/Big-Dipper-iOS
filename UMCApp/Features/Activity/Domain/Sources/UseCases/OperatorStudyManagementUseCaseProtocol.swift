//
//  OperatorStudyManagementUseCaseProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 6/27/26.
//

import Foundation
import UMCFoundation

/// 운영진 스터디 그룹 관리 도메인 진입점
///
/// 운영진 스터디 관리 화면이 수행하는 그룹 CRUD(생성/수정/삭제) · 멤버·멘토 추가/제거 ·
/// 상세 목록 페이지네이션 · 챌린저 ID 해석을 단일 Protocol 로 노출합니다.
/// 모든 액션을 ``StudyRepositoryProtocol`` 에 위임하므로 Presentation 은 Repository 를
/// 직접 알 필요 없이 본 UseCase 에만 의존합니다 (`OperatorAttendanceUseCaseProtocol` 과 동형).
///
/// - Note: 단일 그룹의 멤버 목록 조회는 책임이 다른 `FetchStudyMembersUseCaseProtocol` 이
///   담당합니다. 페이지 커서/기수는 서버 응답이므로 전 레이어를 `String` 으로 통일하며,
///   `Int` 변환은 Repository 가 실제 숫자 비교를 수행하는 연산 시점에만 일어납니다.
public protocol OperatorStudyManagementUseCaseProtocol {

    // MARK: - 조회 / 페이지네이션

    /// 스터디 그룹 상세 목록 페이지 조회
    ///
    /// - Parameters:
    ///   - cursor: 페이지 커서 (첫 페이지는 `nil`, 서버 응답 `String`)
    ///   - size: 페이지 크기
    func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage

    /// 멤버 ID 로 챌린저 ID 조회
    ///
    /// - Parameters:
    ///   - memberId: 멤버 ID (서버 응답 `String`)
    ///   - preferredGeneration: 우선 조회할 기수 (서버 응답 `String`, 없으면 최신 레코드 기준)
    /// - Returns: 조회된 챌린저 ID — 서버 응답이므로 `String?`
    func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String?

    // MARK: - 제출 현황

    /// 관리 가능한 스터디 그룹 이름 목록 조회 (제출 현황 그룹 필터용)
    func fetchStudyGroupNames() async throws -> [StudyGroupName]

    /// 스터디원 워크북 제출 현황 페이지 조회
    ///
    /// - Parameters:
    ///   - studyGroupId: 특정 그룹만 조회 (`nil` 이면 관리 가능한 전체 그룹, 서버 응답 `String`)
    ///   - weekNos: 조회할 주차 번호 목록 (비어 있으면 전체 주차, 서버 응답 `String`)
    ///   - cursor: 직전 페이지 마지막 `studyGroupMemberId` (첫 페이지는 `nil`)
    ///   - size: 페이지 크기 (스터디원 기준)
    func fetchStudyMemberSubmissions(
        studyGroupId: String?,
        weekNos: [String],
        cursor: String?,
        size: Int
    ) async throws -> StudyMemberSubmissionPage

    // MARK: - 그룹 CRUD

    /// 스터디 그룹 생성
    ///
    /// - Parameters:
    ///   - gisuId: 기수 ID (서버 응답 `String`)
    ///   - memberIds: 멤버 ID 목록 (서버 응답 `String`)
    ///   - mentorIds: 멘토 ID 목록 (서버 응답 `String`)
    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws

    /// 스터디 그룹 정보 수정 (이름만 수정 가능)
    func updateStudyGroup(groupId: String, name: String) async throws

    /// 스터디 그룹 삭제
    func deleteStudyGroup(groupId: String) async throws

    // MARK: - 멤버 / 멘토

    /// 스터디 그룹에 스터디원 추가
    func addStudyGroupMember(groupId: String, memberId: String) async throws

    /// 스터디 그룹에서 스터디원 제거
    func removeStudyGroupMember(groupId: String, memberId: String) async throws

    /// 스터디 그룹에 담당 파트장(멘토) 추가
    func addStudyGroupMentor(groupId: String, mentorId: String) async throws

    /// 스터디 그룹에서 담당 파트장(멘토) 제거
    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws
}
