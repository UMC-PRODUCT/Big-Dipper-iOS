//
//  UMCPartType+Color.swift
//  CoreUIComponents
//
//  Created by 이예지 on 5/8/26.
//

import SwiftUI
import UMCFoundation

extension UMCPartType {
    /// 파트별 고유 색상
    public var color: Color {
        switch self {
        case .admin:
            return .indigo
        case .pm:
            return .purple
        case .design:
            return .pink
        case .server(let type):
            switch type {
            case .spring: return .green
            case .node:   return .yellow
            }
        case .front(let type):
            switch type {
            case .web:     return .brown
            case .android: return .teal
            case .ios:     return .orange
            }
        }
    }
}
