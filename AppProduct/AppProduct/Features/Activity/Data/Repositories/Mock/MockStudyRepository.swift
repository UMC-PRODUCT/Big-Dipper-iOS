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
            originalWorkbookId: 1,
            challengerWorkbookId: 1,
            week: 1,
            platform: "iOS",
            title: "SwiftUI 화면 구성 및 상태 관리",
            missionTitle: "@State, @Binding을 활용한 화면 구성 예제를 제출하세요",
            status: .pass
        ),
        .init(
            originalWorkbookId: 2,
            challengerWorkbookId: 2,
            week: 2,
            platform: "iOS",
            title: "SwiftUI 데이터 바인딩 및 MVVM 패턴",
            missionTitle: "MVVM 패턴을 적용한 간단한 앱을 구현하세요",
            status: .pass
        ),
        .init(
            originalWorkbookId: 3,
            challengerWorkbookId: 3,
            week: 3,
            platform: "iOS",
            title: "SwiftUI 리스트와 스크롤뷰, 그리고 네비게이션까지!",
            missionTitle: "List와 NavigationStack을 활용한 화면을 구현하세요",
            status: .pass
        ),
        .init(
            originalWorkbookId: 4,
            challengerWorkbookId: 4,
            week: 4,
            platform: "iOS",
            title: "순간 반응하는 앱 만들기 – Swift 비동기와 Combine",
            missionTitle: "async/await와 Combine을 활용한 비동기 처리 예제를 제출하세요",
            status: .fail
        ),
        .init(
            originalWorkbookId: 5,
            challengerWorkbookId: 5,
            week: 5,
            platform: "iOS",
            title: "API 없이도 앱이 동작하게 – 모델 설계와 JSON 파싱",
            missionTitle: "Codable을 활용한 JSON 파싱 예제를 제출하세요",
            status: .pass
        ),
        .init(
            originalWorkbookId: 6,
            challengerWorkbookId: 6,
            week: 6,
            platform: "iOS",
            title: "진짜 서버랑 대화하기 – Alamofire API 연동 1",
            missionTitle: "Alamofire를 활용한 API 호출 예제를 제출하세요",
            status: .pass
        ),
        .init(
            originalWorkbookId: 7,
            challengerWorkbookId: 7,
            week: 7,
            platform: "iOS",
            title: "Moya로 깔끔하게 통신하기 - API 연동 실전 2",
            missionTitle: "Moya를 활용한 네트워크 레이어 구현 예제를 제출하세요",
            status: .pass
        ),
        .init(
            originalWorkbookId: 8,
            challengerWorkbookId: 8,
            week: 8,
            platform: "iOS",
            title: "좋은 컴포넌트 설계란 무엇일까",
            missionTitle: "함수형 프로그래밍을 적용한 컴포넌트 설계 예제를 제출하세요",
            status: .inProgress
        ),
        .init(
            originalWorkbookId: 9,
            challengerWorkbookId: 9,
            week: 9,
            platform: "iOS",
            title: "UIKit을 SwiftUI에 녹이는 방법 – UIViewControllerRepresentable",
            missionTitle: "UIViewControllerRepresentable을 활용한 UIKit 연동 예제를 제출하세요",
            status: .locked
        ),
        .init(
            originalWorkbookId: 10,
            challengerWorkbookId: 10,
            week: 10,
            platform: "iOS",
            title: "혼자 말고 함께 – iOS 개발 협업 가이드라인",
            missionTitle: "협업 도구와 Git Flow를 활용한 프로젝트 관리 방법을 정리하세요",
            status: .locked
        )
    ]

    // MARK: - StudyRepositoryProtocol

    func fetchCurriculumData() async throws -> CurriculumData {
        async let progress = fetchCurriculumProgress()
        async let missions = fetchMissions()
        return CurriculumData(
            progress: try await progress,
            missions: try await missions
        )
    }

    func fetchCurriculumProgress() async throws -> CurriculumProgressModel {
        // 네트워크 지연 시뮬레이션
        try await Task.sleep(for: .milliseconds(300))

        let completedCount = missions.filter { $0.status == .pass }.count
        return CurriculumProgressModel(
            partName: "iOS PART CURRICULUM",
            curriculumTitle: "좋은 컴포넌트 설계란 무엇일까",
            completedCount: completedCount,
            totalCount: missions.count
        )
    }

    func fetchMissions() async throws -> [MissionCardModel] {
        // 네트워크 지연 시뮬레이션
        try await Task.sleep(for: .milliseconds(200))
        return missions
    }

    func submitMission(
        missionId: Int,
        type: MissionSubmissionType,
        link: String?
    ) async throws {
        // 네트워크 지연 시뮬레이션
        try await Task.sleep(for: .milliseconds(500))

        guard let index = missions.firstIndex(where: {
            ($0.originalWorkbookId ?? $0.challengerWorkbookId) == missionId
        }) else {
            throw DomainError.missionNotFound
        }

        // 상태를 pendingApproval로 변경
        missions[index].status = .pendingApproval
    }

    // MARK: - 운영진 스터디 관리

    func fetchStudyMembers(
        week: Int,
        studyGroupId: Int?
    ) async throws -> [StudyMemberItem] {
        try await Task.sleep(for: .milliseconds(500))
        return StudyMemberItem.preview.filter { $0.week == week }
    }

    func fetchStudyGroups() async throws -> [StudyGroupItem] {
        try await Task.sleep(for: .milliseconds(300))
        return StudyGroupItem.preview
    }

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

    func fetchWeeks() async throws -> [Int] {
        try await Task.sleep(for: .milliseconds(200))
        return Array(1...10)
    }

    func resolveChallengerId(
        memberId: Int,
        preferredGeneration: Int?
    ) async throws -> Int? {
        _ = preferredGeneration
        try await Task.sleep(for: .milliseconds(100))
        return memberId > 0 ? memberId : nil
    }

    func fetchWorkbookSubmissionURL(
        challengerWorkbookId: Int
    ) async throws -> String? {
        try await Task.sleep(for: .milliseconds(150))
        return "https://github.com/user/repo-\(challengerWorkbookId)"
    }

    func reviewWorkbook(
        challengerWorkbookId: Int,
        isApproved: Bool,
        feedback: String
    ) async throws {
        _ = challengerWorkbookId
        _ = isApproved
        _ = feedback
        try await Task.sleep(for: .milliseconds(200))
    }

    func selectBestWorkbook(
        challengerWorkbookId: Int,
        bestReason: String
    ) async throws {
        _ = bestReason
        try await Task.sleep(for: .milliseconds(200))
    }

    func createStudyGroup(
        name: String,
        part: UMCPartType,
        leaderId: Int,
        memberIds: [Int]
    ) async throws {
        _ = name
        _ = part
        _ = leaderId
        _ = memberIds
        try await Task.sleep(for: .milliseconds(300))
    }

    func updateStudyGroupMembers(
        groupId: Int,
        challengerIds: [Int]
    ) async throws {
        _ = groupId
        _ = challengerIds
        try await Task.sleep(for: .milliseconds(300))
    }

    func updateStudyGroup(
        groupId: Int,
        name: String,
        part: UMCPartType
    ) async throws {
        _ = groupId
        _ = name
        _ = part
        try await Task.sleep(for: .milliseconds(300))
    }

    func deleteStudyGroup(
        groupId: Int
    ) async throws {
        _ = groupId
        try await Task.sleep(for: .milliseconds(200))
    }

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
    ) async throws {
        _ = name
        _ = startsAt
        _ = endsAt
        _ = isAllDay
        _ = locationName
        _ = latitude
        _ = longitude
        _ = description
        _ = studyGroupId
        _ = gisuId
        _ = requiresApproval
        try await Task.sleep(for: .milliseconds(300))
    }
}
