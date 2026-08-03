//
//  StubStudyRepository.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import ActivityDomain
import UMCFoundation

/// stub 세션에서 챌린저 스터디 화면을 서버 없이 표시하는 Repository.
///
/// 커리큘럼 조회와 주차 선택지는 픽스처를 반환한다.
/// 운영진 스터디 그룹 관리·변경 기능은 실제 요청으로 넘어가지 않도록 미지원 에러를 던진다.
struct StubStudyRepository: StudyRepositoryProtocol {

    // MARK: - 커리큘럼 / 미션

    func fetchCurriculumOverview() async throws -> CurriculumOverview {
        StubSessionFixtures.curriculumOverview
    }

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        StubSessionFixtures.weeklyCurriculumOptions
    }

    // MARK: - 운영진 스터디 그룹 조회

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        throw StubSessionError.unsupported(action: "스터디 그룹 목록 조회")
    }

    func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        throw StubSessionError.unsupported(action: "스터디 그룹 목록 조회")
    }

    func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
        throw StubSessionError.unsupported(action: "스터디 그룹 상세 조회")
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        throw StubSessionError.unsupported(action: "챌린저 식별자 조회")
    }

    func fetchStudyGroupNames() async throws -> [StudyGroupName] {
        throw StubSessionError.unsupported(action: "스터디 그룹 이름 조회")
    }

    // MARK: - 스터디원 제출 현황

    func fetchStudyMemberSubmissions(
        studyGroupId: String?,
        weekNos: [String],
        cursor: String?,
        size: Int
    ) async throws -> StudyMemberSubmissionPage {
        throw StubSessionError.unsupported(action: "스터디원 제출 현황 조회")
    }

    // MARK: - 운영진 스터디 그룹 CRUD

    func createStudyGroup(
        gisuId: String,
        name: String,
        part: UMCPartType,
        memberIds: [String],
        mentorIds: [String]
    ) async throws {
        throw StubSessionError.unsupported(action: "스터디 그룹 생성")
    }

    func updateStudyGroup(groupId: String, name: String) async throws {
        throw StubSessionError.unsupported(action: "스터디 그룹 수정")
    }

    func deleteStudyGroup(groupId: String) async throws {
        throw StubSessionError.unsupported(action: "스터디 그룹 삭제")
    }

    func addStudyGroupMember(groupId: String, memberId: String) async throws {
        throw StubSessionError.unsupported(action: "스터디원 추가")
    }

    func removeStudyGroupMember(groupId: String, memberId: String) async throws {
        throw StubSessionError.unsupported(action: "스터디원 제거")
    }

    func addStudyGroupMentor(groupId: String, mentorId: String) async throws {
        throw StubSessionError.unsupported(action: "담당 파트장 추가")
    }

    func removeStudyGroupMentor(groupId: String, mentorId: String) async throws {
        throw StubSessionError.unsupported(action: "담당 파트장 제거")
    }

    // MARK: - 그룹-일정 연결

    func linkStudyGroupSchedule(
        scheduleId: String,
        studyGroupId: String,
        weeklyCurriculumId: String
    ) async throws {
        throw StubSessionError.unsupported(action: "스터디 일정 연결")
    }
}
#endif
