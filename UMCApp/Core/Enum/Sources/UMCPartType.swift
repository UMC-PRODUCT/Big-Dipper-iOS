//
//  UMCPartType.swift
//  CoreEnum
//
//  Created by euijjang97 on 5/10/26.
//

import Foundation

/// UMC 동아리의 파트(직무) 유형을 정의하는 열거형입니다.
///
/// UMC는 PM, 디자인, 서버(Spring/Node), 프론트(Web/Android/iOS) 파트로 구성되며,
/// 이 열거형은 각 파트와 세부 기술 스택을 타입 안전하게 표현합니다.
///
/// UI 프로퍼티(color/icon)는 사용처 Presentation 모듈의 extension으로 제공합니다.
public enum UMCPartType: Codable, Equatable, Hashable {

    // MARK: - Cases

    /// 운영진 파트
    case admin

    /// 기획 파트 (Project Manager)
    case pm

    /// 디자인 파트 (UI/UX Designer)
    case design

    /// 서버 파트 (Backend Developer)
    case server(type: ServerType)

    /// 프론트 파트 (Frontend Developer)
    case front(type: FrontType)

    // MARK: - Property

    /// 파트의 표시 이름을 반환합니다.
    public var name: String {
        switch self {
        case .admin:
            return "Admin"
        case .pm:
            return "PM"
        case .design:
            return "Design"
        case .server(let type):
            return type.rawValue
        case .front(let type):
            return type.rawValue
        }
    }

    /// 파트의 정렬 순서를 반환합니다.
    ///
    /// 정렬 순서: PM(0) > Design(1) > Web(2) > iOS(3) > Android(4) > Spring(5) > NodeJS(6)
    public var sortOrder: Int {
        switch self {
        case .admin:
            return -1
        case .pm:
            return 0
        case .design:
            return 1
        case .front(let type):
            switch type {
            case .web:
                return 2
            case .ios:
                return 3
            case .android:
                return 4
            }
        case .server(let type):
            switch type {
            case .spring:
                return 5
            case .node:
                return 6
            }
        }
    }

    /// 모든 파트 조합 (Associated Value로 CaseIterable 불가하여 직접 정의)
    public static let allCases: [UMCPartType] = [
        .pm, .design,
        .server(type: .spring), .server(type: .node),
        .front(type: .web), .front(type: .android),
        .front(type: .ios)
    ]

    // MARK: - Nested Types

    /// 서버 파트의 기술 스택을 정의하는 열거형입니다.
    public enum ServerType: String, Codable, Equatable, Hashable {
        case spring = "Spring"
        case node = "NodeJS"
    }

    /// 프론트 파트의 기술 스택을 정의하는 열거형입니다.
    public enum FrontType: String, Codable, Equatable, Hashable {
        case web = "Web"
        case android = "Android"
        case ios = "iOS"
    }

    // MARK: - API 변환

    /// 서버 API 쿼리 파라미터용 문자열
    public var apiValue: String {
        switch self {
        case .admin:                    return "ADMIN"
        case .pm:                       return "PLAN"
        case .design:                   return "DESIGN"
        case .server(let type):
            switch type {
            case .spring:               return "SPRINGBOOT"
            case .node:                 return "NODEJS"
            }
        case .front(let type):
            switch type {
            case .web:                  return "WEB"
            case .android:              return "ANDROID"
            case .ios:                  return "IOS"
            }
        }
    }

    /// 서버 API 문자열로부터 생성
    public init?(apiValue: String) {
        switch apiValue {
        case "ADMIN":       self = .admin
        case "PLAN":        self = .pm
        case "DESIGN":      self = .design
        case "SPRINGBOOT":  self = .server(type: .spring)
        case "NODEJS":      self = .server(type: .node)
        case "WEB":         self = .front(type: .web)
        case "ANDROID":     self = .front(type: .android)
        case "IOS":         self = .front(type: .ios)
        default:            return nil
        }
    }

    // MARK: - Codable

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)

        guard let part = UMCPartType(apiValue: rawValue) else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid UMCPartType api value: \(rawValue)"
            )
        }
        self = part
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(apiValue)
    }
}
