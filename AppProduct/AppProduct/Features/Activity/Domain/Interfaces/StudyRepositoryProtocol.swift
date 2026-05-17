//
//  StudyRepositoryProtocol.swift
//  AppProduct
//
//  Created by jaewon Lee on 02/01/26.
//

import Foundation

protocol StudyRepositoryProtocol {
    /// 커리큘럼 화면에서 사용하는 데이터(진행률 + 미션 목록)를 가져옵니다.
    /// - Parameter weekNo: 조회할 특정 주차 번호. nil이면 전체 주차를 반환합니다.
    func fetchCurriculumData(weekNo: Int?) async throws -> CurriculumData

    /// 커리큘럼 진행률 정보를 가져옵니다.
    /// - Returns: 커리큘럼 진행률 모델
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func fetchCurriculumProgress() async throws -> CurriculumProgressModel

    /// 미션 목록을 가져옵니다.
    /// - Returns: 미션 카드 모델 배열
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func fetchMissions() async throws -> [MissionCardModel]

    // MARK: - 운영진 스터디 관리

    /// 스터디 그룹 상세 목록을 가져옵니다.
    /// - Returns: 스터디 그룹 상세 모델 배열
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo]

    /// 스터디 그룹 상세 목록을 페이지 단위로 가져옵니다.
    /// - Parameters:
    ///   - cursor: 페이지 커서 (첫 페이지는 nil)
    ///   - size: 페이지 크기
    /// - Returns: 스터디 그룹 상세 페이지 결과
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func fetchStudyGroupDetailsPage(
        cursor: Int?,
        size: Int
    ) async throws -> StudyGroupDetailsPage

    /// 주차 커리큘럼 옵션 목록을 가져옵니다.
    ///
    /// 스터디 그룹 일정을 특정 주차 커리큘럼에 연결할 때 (`POST /api/v1/study-groups/schedules`)
    /// 사용자가 선택할 수 있는 주차 정보(weeklyCurriculumId · weekNo · title)를 반환합니다.
    ///
    /// - Returns: 주차 커리큘럼 옵션 배열 (서버 응답 순서를 유지)
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption]

    /// 멤버 ID로 챌린저 ID를 조회합니다.
    /// - Parameters:
    ///   - memberId: 멤버 ID
    ///   - preferredGeneration: 우선 조회할 기수 (없으면 최신 레코드 기준)
    /// - Returns: 조회된 챌린저 ID (없으면 nil)
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func resolveChallengerId(
        memberId: Int,
        preferredGeneration: Int?
    ) async throws -> Int?

    /// 스터디 그룹을 생성합니다.
    ///
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

    /// 스터디 그룹에 스터디원을 추가합니다.
    /// - Parameters:
    ///   - groupId: 그룹 ID
    ///   - memberId: 추가할 챌린저 ID
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func addStudyGroupMember(
        groupId: Int,
        memberId: Int
    ) async throws

    /// 스터디 그룹에서 스터디원을 제거합니다.
    /// - Parameters:
    ///   - groupId: 그룹 ID
    ///   - memberId: 제거할 챌린저 ID
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func removeStudyGroupMember(
        groupId: Int,
        memberId: Int
    ) async throws

    /// 스터디 그룹에 담당 파트장(멘토)을 추가합니다.
    /// - Parameters:
    ///   - groupId: 그룹 ID
    ///   - mentorId: 추가할 챌린저 ID
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func addStudyGroupMentor(
        groupId: Int,
        mentorId: Int
    ) async throws

    /// 스터디 그룹에서 담당 파트장(멘토)을 제거합니다.
    /// - Parameters:
    ///   - groupId: 그룹 ID
    ///   - mentorId: 제거할 챌린저 ID
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func removeStudyGroupMentor(
        groupId: Int,
        mentorId: Int
    ) async throws

    /// 스터디 그룹 정보를 수정합니다. (이름만 수정 가능)
    /// - Parameters:
    ///   - groupId: 그룹 ID
    ///   - name: 그룹 이름
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func updateStudyGroup(
        groupId: Int,
        name: String
    ) async throws

    /// 스터디 그룹을 삭제합니다.
    /// - Parameters:
    ///   - groupId: 그룹 ID
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func deleteStudyGroup(groupId: Int) async throws

    /// 단일 스터디 그룹 상세 정보를 조회합니다.
    ///
    /// `GET /api/v1/study-groups/{groupId}`
    ///
    /// - Parameter groupId: 조회할 스터디 그룹 ID
    /// - Returns: 멘토와 멤버 목록이 포함된 `StudyGroupInfo` 도메인 모델
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func fetchStudyGroupDetail(groupId: Int) async throws -> StudyGroupInfo

    /// 1단계 V2 일정 생성으로 받은 `scheduleId` 를 스터디 그룹/주차 커리큘럼에 연결합니다.
    ///
    /// `POST /api/v1/study-groups/schedules` 엔드포인트의 단순 래퍼입니다.
    /// 1단계 일정 생성은 `ScheduleRepositoryProtocol.generateSchedule(...)` 으로 호출합니다.
    ///
    /// - Parameters:
    ///   - scheduleId: 1단계에서 생성된 일정 ID
    ///   - studyGroupId: 스터디 그룹 ID
    ///   - weeklyCurriculumId: 주차 커리큘럼 ID
    /// - Throws: 네트워크 오류 또는 파싱 오류 (`SCHEDULE-0009`, `ORGANIZAITON-0023`, `CURRICULUM-0014` 등)
    func linkStudyGroupSchedule(
        scheduleId: Int,
        studyGroupId: Int,
        weeklyCurriculumId: Int
    ) async throws
}
