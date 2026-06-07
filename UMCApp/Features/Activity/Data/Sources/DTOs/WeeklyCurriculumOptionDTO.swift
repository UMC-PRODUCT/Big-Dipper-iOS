//
//  WeeklyCurriculumOptionDTO.swift
//  ActivityData
//
//  Created by jaewon Lee on 6/7/26.
//

import Foundation
import ActivityDomain

// MARK: - WeeklyCurriculumOptionDTO

/// 주차 커리큘럼 선택 옵션 응답 DTO
///
/// ``StudyRepositoryProtocol/fetchWeeklyCurriculumOptions()`` 의 단일 항목.
/// 서버 식별자(`weeklyCurriculumId`)와 주차 번호(`weekNo`)는 모두 `String` 으로 디코딩한다.
struct WeeklyCurriculumOptionDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let weeklyCurriculumId: String
    let weekNo: String
    let title: String

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case weeklyCurriculumId
        case weekNo
        case title
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        weeklyCurriculumId =
            try container.decodeFlexibleStringIfPresent(forKey: .weeklyCurriculumId) ?? ""
        weekNo = try container.decodeFlexibleStringIfPresent(forKey: .weekNo) ?? ""
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(weeklyCurriculumId, forKey: .weeklyCurriculumId)
        try container.encode(weekNo, forKey: .weekNo)
        try container.encode(title, forKey: .title)
    }

    // MARK: - toDomain

    /// DTO 를 도메인 모델 ``WeeklyCurriculumOption`` 으로 변환한다.
    func toDomain() -> WeeklyCurriculumOption {
        WeeklyCurriculumOption(
            weeklyCurriculumId: weeklyCurriculumId,
            weekNo: weekNo,
            title: title
        )
    }
}

// MARK: - WeeklyCurriculumOptionsResponseDTO

/// 주차 커리큘럼 옵션 목록 응답 DTO
///
/// 서버가 `content` 래핑 / `weeklyCurriculums` 키 / 최상위 배열 중 어느 포맷으로 보내도
/// 흡수하도록 유연하게 디코딩한다.
struct WeeklyCurriculumOptionsResponseDTO: Codable, Sendable, Equatable {

    // MARK: - Property

    let options: [WeeklyCurriculumOptionDTO]

    // MARK: - CodingKeys

    private enum CodingKeys: String, CodingKey {
        case content
        case weeklyCurriculums
    }

    // MARK: - Decodable

    init(from decoder: Decoder) throws {
        // 최상위가 배열인 포맷
        if var unkeyed = try? decoder.unkeyedContainer() {
            var decoded: [WeeklyCurriculumOptionDTO] = []
            while !unkeyed.isAtEnd {
                decoded.append(try unkeyed.decode(WeeklyCurriculumOptionDTO.self))
            }
            options = decoded
            return
        }

        // 키 래핑 포맷 (content / weeklyCurriculums)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let content = try container.decodeIfPresent(
            [WeeklyCurriculumOptionDTO].self,
            forKey: .content
        ) {
            options = content
            return
        }
        options = try container.decodeIfPresent(
            [WeeklyCurriculumOptionDTO].self,
            forKey: .weeklyCurriculums
        ) ?? []
    }

    // MARK: - Encodable

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(options, forKey: .content)
    }

    // MARK: - toDomain

    /// DTO 목록을 도메인 모델 ``WeeklyCurriculumOption`` 배열로 변환한다.
    func toDomain() -> [WeeklyCurriculumOption] {
        options.map { $0.toDomain() }
    }
}
