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

    /// 스터디 그룹 일정 생성
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
