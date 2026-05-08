//
//  NoticePart.swift
//  NoticeDomain
//
//  Created by 이예지 on 5/8/26.
//

import Foundation
import UMCFoundation

// MARK: - NoticePart
/// 공지 탭(UI 필터) 전용 파트 타입
public enum NoticePart: String, CaseIterable, Identifiable, Equatable, Hashable {
    case web
    case ios
    case android
    case design
    case plan
    case nodejs
    case springboot

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .web:
            return "Web"
        case .ios:
            return "iOS"
        case .android:
            return "Android"
        case .design:
            return "Design"
        case .plan:
            return "Plan"
        case .nodejs:
            return "Node.js"
        case .springboot:
            return "SpringBoot"
        }
    }

    public var iconName: String {
        switch self {
        case .web:
            return "globe"
        case .ios:
            return "apple.logo"
        case .android:
            return "inset.filled.applewatch.case"
        case .design:
            return "paintpalette.fill"
        case .plan:
            return "doc.text.fill"
        case .nodejs:
            return "hexagon.fill"
        case .springboot:
            return "leaf.fill"
        }
    }

    public var umcPartType: UMCPartType {
        switch self {
        case .web:
            return .front(type: .web)
        case .ios:
            return .front(type: .ios)
        case .android:
            return .front(type: .android)
        case .design:
            return .design
        case .plan:
            return .pm
        case .nodejs:
            return .server(type: .node)
        case .springboot:
            return .server(type: .spring)
        }
    }

    public init?(apiValue: String) {
        guard let part = UMCPartType(apiValue: apiValue) else { return nil }
        self.init(umcPartType: part)
    }

    public init?(umcPartType: UMCPartType) {
        switch umcPartType {
        case .admin:
            return nil
        case .front(let type):
            switch type {
            case .web:
                self = .web
            case .ios:
                self = .ios
            case .android:
                self = .android
            }
        case .design:
            self = .design
        case .pm:
            self = .plan
        case .server(let type):
            switch type {
            case .node:
                self = .nodejs
            case .spring:
                self = .springboot
            }
        }
    }
}
