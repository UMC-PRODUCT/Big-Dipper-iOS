//
//  NoticeEditorTargetDTO.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import NoticeDomain

// MARK: - Chapter List Response
/// 지부 목록 조회 응답 DTO
public struct ChapterListResponseDTO: Codable {
    public let chapters: [ChapterDTO]

    private enum CodingKeys: String, CodingKey {
        case chapters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.chapters = try container.decode([ChapterDTO].self, forKey: .chapters)
    }
}

// MARK: - Chapter
/// 지부 정보 DTO
public struct ChapterDTO: Codable {
    public let id: String
    public let name: String

    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = container.decodeFlexibleOptionalString(forKey: .id) ?? ""
        self.name = try container.decode(String.self, forKey: .name)
    }
}

// MARK: - School List Response
/// 학교 목록 조회 응답 DTO
public struct NoticeEditorSchoolListResponseDTO: Codable {
    public let schools: [NoticeEditorSchoolDTO]

    private enum CodingKeys: String, CodingKey {
        case schools
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schools = try container.decode([NoticeEditorSchoolDTO].self, forKey: .schools)
    }
}

// MARK: - School
/// 학교 정보 DTO
public struct NoticeEditorSchoolDTO: Codable {
    public let schoolId: String
    public let schoolName: String

    private enum CodingKeys: String, CodingKey {
        case schoolId
        case schoolName
    }

    // MARK: - Init
    /// String/Int 혼합 응답을 유연하게 처리합니다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.schoolId = container.decodeFlexibleOptionalString(forKey: .schoolId) ?? ""
        self.schoolName = try container.decode(String.self, forKey: .schoolName)
    }
}

// MARK: - Chapter With Schools Response
/// 기수별 지부/학교 목록 조회 응답 DTO
public struct ChapterWithSchoolsResponseDTO: Codable {
    public let chapters: [ChapterWithSchoolsDTO]

    private enum CodingKeys: String, CodingKey {
        case chapters
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.chapters = try container.decode([ChapterWithSchoolsDTO].self, forKey: .chapters)
    }
}

// MARK: - Chapter With Schools
/// 지부 + 소속 학교 목록 DTO
public struct ChapterWithSchoolsDTO: Codable {
    public let chapterId: String
    public let chapterName: String
    public let schools: [NoticeEditorSchoolDTO]

    private enum CodingKeys: String, CodingKey {
        case chapterId
        case chapterName
        case schools
    }

    // MARK: - Init
    /// String/Int 혼합 응답을 유연하게 처리합니다.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.chapterId = container.decodeFlexibleOptionalString(forKey: .chapterId) ?? ""
        self.chapterName = try container.decode(String.self, forKey: .chapterName)
        self.schools = try container.decode([NoticeEditorSchoolDTO].self, forKey: .schools)
    }
}

// MARK: - Flexible Decoding Helpers

private extension KeyedDecodingContainer {
    func decodeFlexibleOptionalString(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decode(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decode(Double.self, forKey: key) {
            return String(Int(value))
        }
        return nil
    }
}
