//
//  MockStudyRepository.swift
//  AppProduct
//
//  Created by jaewon Lee on 02/01/26.
//

import Foundation

// MARK: - MockStudyRepository

/// Study Repository Mock 구현체
///
/// Preview 및 테스트용 Mock 데이터를 제공합니다.
final class MockStudyRepository: StudyRepositoryProtocol {

    // MARK: - Mock Data

    /// iOS 파트 실제 커리큘럼 (7기 기준)
    private var missions: [MissionCardModel] = [
        .init(
            week: 1,
            platform: "iOS",
            title: "SwiftUI 화면 구성 및 상태 관리",
            missionTitle: "@State, @Binding을 활용한 화면 구성 예제를 제출하세요",
            status: .pass
        ),
        .init(
            week: 2,
            platform: "iOS",
            title: "SwiftUI 데이터 바인딩 및 MVVM 패턴",
            missionTitle: "MVVM 패턴을 적용한 간단한 앱을 구현하세요",
            status: .pass
        ),
        .init(
            week: 3,
            platform: "iOS",
            title: "SwiftUI 리스트와 스크롤뷰, 그리고 네비게이션까지!",
            missionTitle: "List와 NavigationStack을 활용한 화면을 구현하세요",
            status: .pass
        ),
        .init(
            week: 4,
            platform: "iOS",
            title: "순간 반응하는 앱 만들기 – Swift 비동기와 Combine",
            missionTitle: "async/await와 Combine을 활용한 비동기 처리 예제를 제출하세요",
            status: .fail
        ),
        .init(
            week: 5,
            platform: "iOS",
            title: "API 없이도 앱이 동작하게 – 모델 설계와 JSON 파싱",
            missionTitle: "Codable을 활용한 JSON 파싱 예제를 제출하세요",
            status: .pass
        ),
        .init(
            week: 6,
            platform: "iOS",
            title: "진짜 서버랑 대화하기 – Alamofire API 연동 1",
            missionTitle: "Alamofire를 활용한 API 호출 예제를 제출하세요",
            status: .pass
        ),
        .init(
            week: 7,
            platform: "iOS",
            title: "Moya로 깔끔하게 통신하기 - API 연동 실전 2",
            missionTitle: "Moya를 활용한 네트워크 레이어 구현 예제를 제출하세요",
            status: .pass
        ),
        .init(
            week: 8,
            platform: "iOS",
            title: "좋은 컴포넌트 설계란 무엇일까",
            missionTitle: "함수형 프로그래밍을 적용한 컴포넌트 설계 예제를 제출하세요",
            status: .inProgress
        ),
        .init(
            week: 9,
            platform: "iOS",
            title: "UIKit을 SwiftUI에 녹이는 방법 – UIViewControllerRepresentable",
            missionTitle: "UIViewControllerRepresentable을 활용한 UIKit 연동 예제를 제출하세요",
            status: .locked
        ),
        .init(
            week: 10,
            platform: "iOS",
            title: "혼자 말고 함께 – iOS 개발 협업 가이드라인",
            missionTitle: "협업 도구와 Git Flow를 활용한 프로젝트 관리 방법을 정리하세요",
            status: .locked
        )
    ]

    // MARK: - StudyRepositoryProtocol

    func fetchCurriculumData(weekNo: Int?) async throws -> CurriculumData {
        _ = weekNo
        try await Task.sleep(for: .milliseconds(300))

        let completedCount = missions.filter { $0.status == .pass }.count
        let progress = CurriculumProgressModel(
            partType: .front(type: .ios),
            partName: "iOS PART CURRICULUM",
            curriculumTitle: "좋은 컴포넌트 설계란 무엇일까",
            completedCount: completedCount,
            totalCount: missions.count
        )
        return CurriculumData(progress: progress, missions: missions)
    }

    func fetchCurriculumProgress() async throws -> CurriculumProgressModel {
        try await fetchCurriculumData(weekNo: nil).progress
    }

    func fetchMissions() async throws -> [MissionCardModel] {
        try await fetchCurriculumData(weekNo: nil).missions
    }

    // MARK: - 운영진 스터디 관리

    func fetchStudyGroupDetails() async throws -> [StudyGroupInfo] {
        try await Task.sleep(for: .milliseconds(300))
        return StudyGroupPreviewData.groups
    }

    func fetchStudyGroupDetailsPage(
        cursor: Int?,
        size: Int
    ) async throws -> StudyGroupDetailsPage {
        try await Task.sleep(for: .milliseconds(300))

        let allGroups = StudyGroupPreviewData.groups
        let startIndex = max(cursor ?? 0, 0)
        guard startIndex < allGroups.count else {
            return StudyGroupDetailsPage(
                content: [],
                hasNext: false,
                nextCursor: nil
            )
        }

        let pageSize = max(size, 1)
        let endIndex = min(startIndex + pageSize, allGroups.count)
        let pageContent = Array(allGroups[startIndex..<endIndex])
        let hasNext = endIndex < allGroups.count

        return StudyGroupDetailsPage(
            content: pageContent,
            hasNext: hasNext,
            nextCursor: hasNext ? endIndex : nil
        )
    }

    func fetchWeeklyCurriculumOptions() async throws -> [WeeklyCurriculumOption] {
        try await Task.sleep(for: .milliseconds(200))
        return missions.map {
            WeeklyCurriculumOption(
                weeklyCurriculumId: $0.week,
                weekNo: $0.week,
                title: $0.title
            )
        }
    }

    func resolveChallengerId(
        memberId: Int,
        preferredGeneration: Int?
    ) async throws -> Int? {
        _ = preferredGeneration
        try await Task.sleep(for: .milliseconds(100))
        return memberId > 0 ? memberId : nil
    }

    func createStudyGroup(
        gisuId: Int,
        name: String,
        part: UMCPartType,
        memberIds: [Int],
        mentorIds: [Int]
    ) async throws {
        _ = gisuId
        _ = name
        _ = part
        _ = memberIds
        _ = mentorIds
        try await Task.sleep(for: .milliseconds(300))
    }

    func addStudyGroupMember(
        groupId: Int,
        memberId: Int
    ) async throws {
        _ = groupId
        _ = memberId
        try await Task.sleep(for: .milliseconds(200))
    }

    func removeStudyGroupMember(
        groupId: Int,
        memberId: Int
    ) async throws {
        _ = groupId
        _ = memberId
        try await Task.sleep(for: .milliseconds(200))
    }

    func addStudyGroupMentor(
        groupId: Int,
        mentorId: Int
    ) async throws {
        _ = groupId
        _ = mentorId
        try await Task.sleep(for: .milliseconds(200))
    }

    func removeStudyGroupMentor(
        groupId: Int,
        mentorId: Int
    ) async throws {
        _ = groupId
        _ = mentorId
        try await Task.sleep(for: .milliseconds(200))
    }

    func updateStudyGroup(
        groupId: Int,
        name: String
    ) async throws {
        _ = groupId
        _ = name
        try await Task.sleep(for: .milliseconds(300))
    }

    func deleteStudyGroup(
        groupId: Int
    ) async throws {
        _ = groupId
        try await Task.sleep(for: .milliseconds(200))
    }

    func fetchStudyGroupDetail(groupId: Int) async throws -> StudyGroupInfo {
        _ = groupId
        try await Task.sleep(for: .milliseconds(200))
        return StudyGroupInfo.preview
    }

    func linkStudyGroupSchedule(
        scheduleId: Int,
        studyGroupId: Int,
        weeklyCurriculumId: Int
    ) async throws {
        _ = scheduleId
        _ = studyGroupId
        _ = weeklyCurriculumId
        try await Task.sleep(for: .milliseconds(300))
    }
}
