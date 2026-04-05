//
//  CurriculumProgressModel.swift
//  AppProduct
//
//  Created by jaewon Lee on 02/01/26.
//

import SwiftUI

// MARK: - CurriculumProgressModel

/// 커리큘럼 진행률 데이터 모델
struct CurriculumProgressModel: Equatable, Identifiable {

    // MARK: - Property

    let id: UUID
    let partType: UMCPartType?
    let partName: String
    let curriculumTitle: String
    let completedCount: Int
    let totalCount: Int
    let openedCount: Int

    // MARK: - Computed Property

    /// 열린 미션 비율 (0.0 ~ 1.0)
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(openedCount) / Double(totalCount)
    }

    /// 열린 미션 퍼센트 (0 ~ 100)
    var progressPercentage: Int {
        Int(progress * 100)
    }

    /// 열림 텍스트 (예: "2/8 열림")
    var completionText: String {
        "\(openedCount)/\(totalCount) 열림"
    }

    /// 파트 메인 컬러
    var partColor: Color {
        if let partType {
            return partType.color
        }

        return parsedPartType?.color ?? .indigo500
    }

    // MARK: - Private Property

    private var parsedPartType: UMCPartType? {
        let normalizedPart = partName
            .replacingOccurrences(of: " PART CURRICULUM", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        switch normalizedPart {
        case "PLAN":
            return .pm
        case "PM":
            return .pm
        case "DESIGN":
            return .design
        case "WEB":
            return .front(type: .web)
        case "ANDROID":
            return .front(type: .android)
        case "IOS":
            return .front(type: .ios)
        case "SPRING", "SPRINGBOOT":
            return .server(type: .spring)
        case "SERVER":
            return .server(type: .spring)
        case "NODE", "NODEJS":
            return .server(type: .node)
        default:
            return nil
        }
    }

    // MARK: - Initializer

    init(
        id: UUID = UUID(),
        partType: UMCPartType? = nil,
        partName: String,
        curriculumTitle: String,
        completedCount: Int,
        totalCount: Int,
        openedCount: Int = 0
    ) {
        self.id = id
        self.partType = partType
        self.partName = partName
        self.curriculumTitle = curriculumTitle
        self.completedCount = completedCount
        self.totalCount = totalCount
        self.openedCount = openedCount
    }
}
