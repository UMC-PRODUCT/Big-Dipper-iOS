//
//  CurriculumProgressModel+PartColor.swift
//  ActivityPresentation
//
//  Created by jaewon Lee on 7/15/26.
//

import SwiftUI
import ActivityDomain
import CoreDesignSystem
import CoreUIComponents
import UMCFoundation

/// `CurriculumProgressModel` 의 파트 색상 매핑.
///
/// 도메인 모델은 SwiftUI 의존을 갖지 않으므로 파트 컬러 계산은 Presentation 레이어에서
/// 제공합니다. `partType` 이 있으면 그대로 쓰고, 없으면 `partName` 을 파싱해 추론하며,
/// 그마저 실패하면 브랜드 기본색(`indigo500`)으로 폴백합니다.
extension CurriculumProgressModel {

    /// 파트 메인 컬러
    var partColor: Color {
        if let partType {
            return partType.color
        }

        return parsedPartType?.color ?? .indigo500
    }

    /// `partName` 문자열에서 파트 타입을 추론합니다. (`partType` 부재 시 폴백 경로)
    private var parsedPartType: UMCPartType? {
        let normalizedPart = partName
            .replacingOccurrences(of: " PART CURRICULUM", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()

        switch normalizedPart {
        case "PLAN", "PM":
            return .pm
        case "DESIGN":
            return .design
        case "WEB":
            return .front(type: .web)
        case "ANDROID":
            return .front(type: .android)
        case "IOS":
            return .front(type: .ios)
        case "SPRING", "SPRINGBOOT", "SERVER":
            return .server(type: .spring)
        case "NODE", "NODEJS":
            return .server(type: .node)
        default:
            return nil
        }
    }
}
