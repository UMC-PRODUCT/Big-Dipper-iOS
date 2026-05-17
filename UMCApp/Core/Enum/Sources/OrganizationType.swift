//
//  OrganizationType.swift
//  CoreEnum
//

import Foundation

/// 운영 조직 유형
public enum OrganizationType: String, Codable, Equatable, Hashable {
    /// 중앙
    case central = "CENTRAL"
    /// 지부
    case chapter = "CHAPTER"
    /// 학교
    case school = "SCHOOL"
}
