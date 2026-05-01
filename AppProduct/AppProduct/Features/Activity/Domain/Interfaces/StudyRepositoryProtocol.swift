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

    /// 스터디원 목록을 가져옵니다.
    /// - Parameters:
    ///   - week: 조회 주차
    ///   - studyGroupId: 특정 그룹 ID (nil이면 전체 그룹)
    /// - Returns: 스터디원 모델 배열
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func fetchStudyMembers(
        week: Int,
        studyGroupId: Int?
    ) async throws -> [StudyMemberItem]

    /// 스터디 그룹 목록을 가져옵니다.
    /// - Returns: 스터디 그룹 모델 배열
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func fetchStudyGroups() async throws -> [StudyGroupItem]

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

    /// 스터디 주차 목록을 가져옵니다.
    /// - Returns: 주차 번호 배열
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func fetchWeeks() async throws -> [Int]

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

    /// 챌린저 워크북 제출 URL을 조회합니다. (운영진 전용)
    /// - Parameter challengerWorkbookId: 챌린저 워크북 ID
    /// - Returns: 제출 URL 문자열 (없으면 nil)
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func fetchWorkbookSubmissionURL(
        challengerWorkbookId: Int
    ) async throws -> String?

    /// 챌린저 워크북을 검토합니다.
    /// - Parameters:
    ///   - challengerWorkbookId: 챌린저 워크북 ID
    ///   - isApproved: 통과 여부 (true: PASS, false: FAIL)
    ///   - feedback: 피드백 내용
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func reviewWorkbook(
        challengerWorkbookId: Int,
        isApproved: Bool,
        feedback: String
    ) async throws

    /// 베스트 워크북으로 선정합니다.
    /// - Parameters:
    ///   - challengerWorkbookId: 챌린저 워크북 ID
    ///   - bestReason: 선정 사유
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func selectBestWorkbook(
        challengerWorkbookId: Int,
        bestReason: String
    ) async throws

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

    /// 스터디 그룹 일정을 생성합니다.
    ///
    /// - Parameters:
    ///   - name: 일정 이름
    ///   - startsAt: 시작 일시
    ///   - endsAt: 종료 일시
    ///   - isAllDay: 종일 여부
    ///   - locationName: 장소명
    ///   - latitude: 위도
    ///   - longitude: 경도
    ///   - description: 일정 설명
    ///   - studyGroupId: 스터디 그룹 ID
    ///   - gisuId: 기수 ID
    ///   - requiresApproval: 승인 필요 여부
    /// - Throws: 네트워크 오류 또는 파싱 오류
    func createStudyGroupSchedule(
        name: String,
        startsAt: Date,
        endsAt: Date,
        isAllDay: Bool,
        locationName: String,
        latitude: Double,
        longitude: Double,
        description: String,
        studyGroupId: Int,
        gisuId: Int,
        requiresApproval: Bool
    ) async throws
}
