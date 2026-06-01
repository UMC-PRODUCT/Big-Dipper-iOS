//
//  CurriculumProgressModel.swift
//  ActivityDomain
//
//  Created by jaewon Lee on 5/11/26.
//

import Foundation
import UMCFoundation

/// 커리큘럼 진행률 데이터 모델
///
/// 한 파트(`partType`/`partName`)의 커리큘럼 종료 진척도를 표현합니다.
/// UI 색상 매핑은 Presentation 레이어 extension에서 제공합니다.
public struct CurriculumProgressModel: Equatable, Identifiable {

    // MARK: - Property

    public let id: UUID
    public let partType: UMCPartType?
    public let partName: String
    public let curriculumTitle: String
    public let completedCount: Int
    public let totalCount: Int

    // MARK: - Computed Property

    /// 종료된 주차 비율 (0.0 ~ 1.0). `totalCount` 가 0 이면 0 반환.
    public var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    /// 종료된 주차 퍼센트 (0 ~ 100)
    public var progressPercentage: Int {
        Int(progress * 100)
    }

    /// 완료 텍스트 (예: "2/8 완료")
    public var completionText: String {
        "\(completedCount)/\(totalCount) 완료"
    }

    // MARK: - Initializer

    public init(
        id: UUID = UUID(),
        partType: UMCPartType? = nil,
        partName: String,
        curriculumTitle: String,
        completedCount: Int,
        totalCount: Int
    ) {
        self.id = id
        self.partType = partType
        self.partName = partName
        self.curriculumTitle = curriculumTitle
        self.completedCount = completedCount
        self.totalCount = totalCount
    }
}
