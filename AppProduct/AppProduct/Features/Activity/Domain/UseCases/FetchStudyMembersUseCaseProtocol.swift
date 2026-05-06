//
//  FetchStudyMembersUseCaseProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 2/9/26.
//

import Foundation

// MARK: - Protocol

protocol FetchStudyMembersUseCaseProtocol {
    /// 스터디원 목록 조회
    func fetchMembers(
        week: Int,
        studyGroupId: Int?
    ) async throws -> [StudyMemberItem]

    /// 스터디 그룹 목록 조회
    func fetchStudyGroups() async throws -> [StudyGroupItem]

    /// 스터디 그룹 상세 목록 조회
    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo]

    /// 스터디 그룹 상세 목록 페이지 조회
    func fetchStudyGroupDetailsPage(
        cursor: Int?,
        size: Int
    ) async throws -> StudyGroupDetailsPage

    /// 스터디 주차 목록 조회
    func fetchWeeks() async throws -> [Int]

    /// 주차 커리큘럼 옵션(weeklyCurriculumId · weekNo · title) 목록 조회
    ///
    /// 스터디 그룹 일정 등록 화면에서 어느 주차 커리큘럼에 연결할지 선택할 때 사용합니다.
    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption]

    /// 멤버 ID를 챌린저 ID로 변환
    func resolveChallengerId(
        memberId: Int,
        preferredGeneration: Int?
    ) async throws -> Int?

    /// 챌린저 워크북 제출 URL 조회
    func fetchWorkbookSubmissionURL(
        challengerWorkbookId: Int
    ) async throws -> String?

    /// 챌린저 워크북 검토
    func reviewWorkbook(
        challengerWorkbookId: Int,
        isApproved: Bool,
        feedback: String
    ) async throws

    /// 베스트 워크북 선정
    func selectBestWorkbook(
        challengerWorkbookId: Int,
        bestReason: String
    ) async throws

    /// 스터디 그룹 생성
    /// - Parameters:
    ///   - gisuId: 기수 ID
    ///   - name: 그룹 이름
    ///   - part: 스터디 파트
    ///   - memberIds: 스터디원 챌린저 ID 목록
    ///   - mentorIds: 담당 파트장(멘토) 챌린저 ID 목록
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func createStudyGroup(
        gisuId: Int,
        name: String,
        part: UMCPartType,
        memberIds: [Int],
        mentorIds: [Int]
    ) async throws

    /// 스터디 그룹에 스터디원 추가
    func addStudyGroupMember(groupId: Int, memberId: Int) async throws

    /// 스터디 그룹에서 스터디원 제거
    func removeStudyGroupMember(groupId: Int, memberId: Int) async throws

    /// 스터디 그룹에 담당 파트장(멘토) 추가
    func addStudyGroupMentor(groupId: Int, mentorId: Int) async throws

    /// 스터디 그룹에서 담당 파트장(멘토) 제거
    func removeStudyGroupMentor(groupId: Int, mentorId: Int) async throws

    /// 스터디 그룹 수정 (이름만 수정 가능)
    func updateStudyGroup(
        groupId: Int,
        name: String
    ) async throws

    /// 스터디 그룹 삭제
    /// - Parameters:
    ///   - groupId: 그룹 ID
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func deleteStudyGroup(groupId: Int) async throws

    /// 스터디 그룹 일정 — 1단계 V2 일정 생성
    ///
    /// `POST /api/v2/schedules` 를 호출해 일반 일정을 만들고 `scheduleId` 를 반환합니다.
    /// 본 메서드는 호출자가 참여자에서 본인을 제외한 멤버 ID 와 출석 정책 등을 채워서 전달합니다.
    func createStudySchedule(
        request: GenerateScheduleRequetDTO
    ) async throws -> Int

    /// 스터디 그룹 일정 — 2단계 스터디 그룹/주차 커리큘럼 연결
    ///
    /// `POST /api/v1/study-groups/schedules`
    func linkStudyGroupSchedule(
        scheduleId: Int,
        studyGroupId: Int,
        weeklyCurriculumId: Int
    ) async throws

    /// 일정 단순 삭제 (스터디 그룹 일정 2단계 실패 시 베스트 에포트 롤백 용)
    func deleteSchedule(scheduleId: Int) async throws
}
