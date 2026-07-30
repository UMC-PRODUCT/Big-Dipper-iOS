//
//  MissionPreviewData.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

#if DEBUG
import Foundation
import ActivityDomain

/// 미션/커리큘럼 프리뷰에서 사용하는 더미 데이터 모음.
///
/// 프리뷰 전용이므로 파일 전체를 `#if DEBUG` 로 가드합니다.
enum MissionPreviewData {

    // MARK: - Single Mission

    static let singleMission = MissionCardModel(
        week: 7,
        platform: "iOS",
        title: "Moya로 깔끔하게 통신하기 - API 연동 실전 2",
        missionTitle: "Moya를 활용한 네트워크 레이어 구현 예제를 제출하세요",
        status: .inProgress
    )

    // MARK: - Platform-specific Missions

    /// iOS 파트 커리큘럼 (프리뷰용)
    static let iosMissions: [MissionCardModel] = [
        .init(
            week: 0,
            platform: "iOS",
            title: "SwiftUI 기본 개념",
            missionTitle: "SwiftUI 기본 개념을 학습하고 정리한 글 링크를 제출하세요",
            status: .pass
        ),
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
            status: .inProgress
        ),
        .init(
            week: 8,
            platform: "iOS",
            title: "좋은 컴포넌트 설계란 무엇일까",
            missionTitle: "함수형 프로그래밍을 적용한 컴포넌트 설계 예제를 제출하세요",
            status: .locked
        )
    ]

    static let webMissions: [MissionCardModel] = [
        .init(
            week: 1,
            platform: "Web",
            title: "React 기초",
            missionTitle: "React 컴포넌트를 활용한 예제를 제출하세요",
            status: .pass
        ),
        .init(
            week: 2,
            platform: "Web",
            title: "상태 관리",
            missionTitle: "Redux 또는 Zustand를 활용한 상태 관리 예제를 제출하세요",
            status: .inProgress
        )
    ]

    // MARK: - Status-specific Missions

    /// 모든 상태를 포함하는 미션 목록 (프리뷰용)
    static let allStatusMissions: [MissionCardModel] = [
        .init(
            week: 0,
            platform: "iOS",
            title: "SwiftUI 기본 개념",
            missionTitle: "SwiftUI 기본 개념을 학습하고 정리한 글 링크를 제출하세요",
            status: .pass
        ),
        .init(
            week: 1,
            platform: "iOS",
            title: "SwiftUI 화면 구성 및 상태 관리",
            missionTitle: "@State, @Binding을 활용한 화면 구성 예제를 제출하세요",
            status: .fail
        ),
        .init(
            week: 2,
            platform: "iOS",
            title: "SwiftUI 데이터 바인딩 및 MVVM 패턴",
            missionTitle: "MVVM 패턴을 적용한 간단한 앱을 구현하세요",
            status: .pendingApproval
        ),
        .init(
            week: 3,
            platform: "iOS",
            title: "SwiftUI 리스트와 스크롤뷰, 그리고 네비게이션까지!",
            missionTitle: "List와 NavigationStack을 활용한 화면을 구현하세요",
            status: .inProgress
        ),
        .init(
            week: 4,
            platform: "iOS",
            title: "순간 반응하는 앱 만들기 – Swift 비동기와 Combine",
            missionTitle: "async/await와 Combine을 활용한 비동기 처리 예제를 제출하세요",
            status: .notStarted
        ),
        .init(
            week: 5,
            platform: "iOS",
            title: "API 없이도 앱이 동작하게 – 모델 설계와 JSON 파싱",
            missionTitle: "Codable을 활용한 JSON 파싱 예제를 제출하세요",
            status: .locked
        )
    ]

    // MARK: - Curriculum Progress

    static let sampleProgress = CurriculumProgressModel(
        partName: "iOS PART CURRICULUM",
        curriculumTitle: "Swift 기초 문법",
        completedCount: 2,
        totalCount: 8
    )
}

// MARK: - Preview ViewModel

extension MissionPreviewData {

    /// 프리뷰용 `ChallengerStudyViewModel` 을 조립합니다.
    ///
    /// 실제 UseCase 대신 결정론적 stub UseCase 를 주입해 네트워크 없이 화면을 구성합니다.
    @MainActor
    static func makeViewModel(
        progress: CurriculumProgressModel = sampleProgress,
        missions: [MissionCardModel] = iosMissions
    ) -> ChallengerStudyViewModel {
        ChallengerStudyViewModel(
            fetchCurriculumOverviewUseCase: PreviewFetchCurriculumOverviewUseCase(
                overview: CurriculumOverview(progress: progress, missions: missions)
            )
        )
    }
}

// MARK: - Preview Stub UseCase

private struct PreviewFetchCurriculumOverviewUseCase: FetchCurriculumOverviewUseCaseProtocol {
    let overview: CurriculumOverview
    func execute() async throws -> CurriculumOverview { overview }
}
#endif
