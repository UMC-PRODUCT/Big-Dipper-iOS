//
//  SchoolListResponseDTO.swift
//  AuthData
//
//  Created by euijjang97 on 7/9/26.
//

import AuthDomain
import UMCFoundation

/// 학교 목록 API 응답 DTO
public struct SchoolListResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 학교 목록
    public let schools: [SchoolDTO]

    private enum CodingKeys: String, CodingKey {
        case schools
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schools = try container.decodeIfPresent([SchoolDTO].self, forKey: .schools) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schools, forKey: .schools)
    }
}

/// 학교 정보 DTO
public struct SchoolDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    /// 학교 ID (서버가 String 반환, Int로 흔들릴 수 있어 flexible 디코딩)
    public let schoolId: String
    /// 학교 이름
    public let schoolName: String

    private enum CodingKeys: String, CodingKey {
        case schoolId
        case schoolName
    }

    // MARK: - Init

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schoolId = container.decodeFlexibleStringOrEmpty(forKey: .schoolId)
        schoolName = try container.decodeIfPresent(String.self, forKey: .schoolName) ?? ""
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schoolId, forKey: .schoolId)
        try container.encode(schoolName, forKey: .schoolName)
    }
}

// MARK: - Mapping

extension SchoolDTO {
    /// Domain 모델로 변환
    func toDomain() -> School {
        School(id: schoolId, name: schoolName)
    }
}
