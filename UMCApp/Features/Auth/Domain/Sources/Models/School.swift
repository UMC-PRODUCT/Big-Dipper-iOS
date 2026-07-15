//
//  School.swift
//  AuthDomain
//
//  Created by euijjang97 on 7/9/26.
//

/// 학교 도메인 모델
public struct School: Equatable, Sendable {

    // MARK: - Property

    public let id: String
    public let name: String

    // MARK: - Init

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}
