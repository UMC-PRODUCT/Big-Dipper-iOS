//
//  StubStudyRepository.swift
//  UMCApp
//
//  Created by jaewon Lee on 8/3/26.
//

#if DEBUG
import ActivityDomain
import UMCFoundation

/// stub 세션에서 스터디 화면(챌린저·운영진)을 서버 없이 표시하는 Repository.
///
/// 커리큘럼·스터디 그룹·제출 현황 조회는 픽스처를 반환한다.
/// 그룹 CRUD·멤버/멘토 변경 등 서버에 반영돼야 하는 쓰기 액션은 실제 요청으로 넘어가지
/// 않도록 미지원 에러를 던진다.
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
        StubSessionFixtures.studyGroups
    }

    func fetchStudyGroupDetailsPage(
        cursor: String?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        StudyGroupDetailsPage(
            content: StubSessionFixtures.studyGroups,
            hasNext: false,
            nextCursor: nil
        )
    }

    func fetchStudyGroupDetail(groupId: String) async throws -> StudyGroupInfo {
        guard
            let group = StubSessionFixtures.studyGroups
                .first(where: { $0.serverID == groupId })
        else {
            throw StubSessionError.unsupported(action: "스터디 그룹 상세 조회")
        }
        return group
    }

    func resolveChallengerId(
        memberId: String,
        preferredGeneration: String?
    ) async throws -> String? {
        throw StubSessionError.unsupported(action: "챌린저 식별자 조회")
    }

    func fetchStudyGroupNames() async throws -> [StudyGroupName] {
        StubSessionFixtures.studyGroups.map {
            StudyGroupName(groupId: $0.serverID, name: $0.name)
        }
    }

    // MARK: - 스터디원 제출 현황

    func fetchStudyMemberSubmissions(
        studyGroupId: String?,
        weekNos: [String],
        cursor: String?,
        size: Int
    ) async throws -> StudyMemberSubmissionPage {
        var rows = StubSessionFixtures.studyMemberSubmissions
        if let studyGroupId {
            rows = rows.filter { $0.studyGroupId == studyGroupId }
        }
        if !weekNos.isEmpty {
            let weekSet = Set(weekNos)
            rows = rows.compactMap { row in
                let matched = row.weeks.filter { weekSet.contains($0.weekNo) }
                guard !matched.isEmpty else { return nil }
                return StudyMemberSubmission(
                    studyGroupMemberId: row.studyGroupMemberId,
                    memberId: row.memberId,
                    memberName: row.memberName,
                    nickname: row.nickname,
                    schoolName: row.schoolName,
                    profileImageURL: row.profileImageURL,
                    studyGroupId: row.studyGroupId,
                    studyGroupName: row.studyGroupName,
                    part: row.part,
                    partLabel: row.partLabel,
                    weeks: matched
                )
            }
        }
        return StudyMemberSubmissionPage(content: rows, hasNext: false, nextCursor: nil)
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
