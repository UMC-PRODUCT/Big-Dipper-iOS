//
//  Generation.swift
//  UMCFoundation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation

// MARK: - Generation
/// 기수 모델
public struct Generation: Identifiable, Equatable, Hashable {
    public let value: String
    public var id: String { value }
    public var title: String { "\(value)기" }
    
    public init(value: String) {
        self.value = value
    }
}
