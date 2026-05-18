//
//  StudyRepositoryProtocol.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/17/26.
//

import Foundation
import UMCFoundation

/// 스터디 도메인 데이터 접근 Repository
///
/// 커리큘럼 진행률/미션 조회, 운영진 스터디 그룹 CRUD, 그룹-일정 연결 등을 담당합니다.
public protocol StudyRepositoryProtocol {

    // MARK: - 커리큘럼 / 미션

    /// 커리큘럼 진행률 정보 조회
    func fetchCurriculumProgress() async throws -> CurriculumProgressModel

    /// 미션 목록 조회
    func fetchMissions() async throws -> [MissionCardModel]

    /// 주차 커리큘럼 옵션 목록 조회
    ///
    /// ``linkStudyGroupSchedule(scheduleId:studyGroupId:weeklyCurriculumId:)``
    /// 의 `weeklyCurriculumId` 선택지로 사용됩니다.
    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption]

    // MARK: - 운영진 스터디 그룹 조회

    /// 스터디 그룹 상세 목록 전체 조회
    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo]

    /// 스터디 그룹 상세 목록 페이지 조회
    ///
    /// - Parameters:
    ///   - cursor: 페이지 커서 (첫 페이지는 `nil`)
    ///   - size: 페이지 크기
    func fetchStudyGroupDetailsPage(
        cursor: Int?,
        size: Int
    ) async throws -> StudyGroupDetailsPage

    /// 단일 스터디 그룹 상세 조회
    ///
    /// `GET /api/v1/study-groups/{groupId}`
    func fetchStudyGroupDetail(groupId: Int) async throws -> StudyGroupInfo

    /// 멤버 ID 로 챌린저 ID 조회
    ///
    /// - Parameters:
    ///   - memberId: 멤버 ID
    ///   - preferredGeneration: 우선 조회할 기수 (없으면 최신 레코드 기준)
    /// - Returns: 조회된 챌린저 ID (없으면 `nil`)
    func resolveChallengerId(
        memberId: Int,
        preferredGeneration: Int?
    ) async throws -> Int?

    // MARK: - 운영진 스터디 그룹 CRUD

    /// 스터디 그룹 생성
    func createStudyGroup(
        gisuId: Int,
        name: String,
        part: UMCPartType,
        memberIds: [Int],
        mentorIds: [Int]
    ) async throws

    /// 스터디 그룹 정보 수정 (이름만 수정 가능)
    func updateStudyGroup(groupId: Int, name: String) async throws

    /// 스터디 그룹 삭제
    func deleteStudyGroup(groupId: Int) async throws

    /// 스터디 그룹에 스터디원 추가
    func addStudyGroupMember(groupId: Int, memberId: Int) async throws

    /// 스터디 그룹에서 스터디원 제거
    func removeStudyGroupMember(groupId: Int, memberId: Int) async throws

    /// 스터디 그룹에 담당 파트장(멘토) 추가
    func addStudyGroupMentor(groupId: Int, mentorId: Int) async throws

    /// 스터디 그룹에서 담당 파트장(멘토) 제거
    func removeStudyGroupMentor(groupId: Int, mentorId: Int) async throws

    // MARK: - 그룹-일정 연결

    /// 일정 생성 후 받은 `scheduleId` 를 스터디 그룹/주차 커리큘럼에 연결
    ///
    /// `POST /api/v1/study-groups/schedules` 엔드포인트의 단순 래퍼.
    /// 1단계 일정 생성은 별도 `ScheduleRepositoryProtocol.generateSchedule(...)` 사용.
    func linkStudyGroupSchedule(
        scheduleId: Int,
        studyGroupId: Int,
        weeklyCurriculumId: Int
    ) async throws

    // MARK: - 외부 도메인 의존 (별도 이슈로 추가 예정)
    //
    // `fetchCurriculumData(weekNo:) async throws -> CurriculumData`
    // 는 `CurriculumData` 의 정의 위치가 미확정 (별도 모듈/Feature 가능)이라 본 PR 에서 제외.
    // 정의 위치 확정 후 후속 이슈에서 추가합니다.
}
