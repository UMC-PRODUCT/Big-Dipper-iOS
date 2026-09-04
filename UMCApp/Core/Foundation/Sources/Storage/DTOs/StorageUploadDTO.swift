//
//  StorageUploadDTO.swift
//  UMCFoundation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation

// MARK: - Prepare Upload Request

/// 파일 업로드 준비 요청 DTO (Presigned URL 발급용)
///
/// Request(Encodable) DTO이므로 synthesized Codable을 사용합니다. (핵심 규칙 #3 예외)
public struct StoragePrepareUploadRequestDTO: Codable {
    public let fileName: String
    public let contentType: String
    public let fileSize: Int
    public let category: StorageFileCategory

    public init(
        fileName: String,
        contentType: String,
        fileSize: Int,
        category: StorageFileCategory
    ) {
        self.fileName = fileName
        self.contentType = contentType
        self.fileSize = fileSize
        self.category = category
    }
}

// MARK: - Prepare Upload Response

/// 파일 업로드 준비 응답 DTO (Presigned URL + 헤더 포함)
///
/// 서버 응답 DTO이므로 custom `init(from:)` + `encode(to:)`를 사용합니다. (핵심 규칙 #3)
/// 서버가 식별자(`fileId`)를 정수/문자열 어느 쪽으로 직렬화해도 흡수하도록
/// `decodeFlexibleString`으로 디코딩합니다. (핵심 규칙 #2)
public struct StoragePrepareUploadResponseDTO: Codable {
    public let fileId: String
    public let uploadUrl: String
    public let uploadMethod: String
    public let headers: [String: String]?
    public let expiresAt: String?

    enum CodingKeys: String, CodingKey {
        case fileId
        case uploadUrl
        case uploadMethod
        case headers
        case expiresAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fileId = try container.decodeFlexibleString(forKey: .fileId)
        uploadUrl = try container.decode(String.self, forKey: .uploadUrl)
        uploadMethod = try container.decode(String.self, forKey: .uploadMethod)
        headers = try container.decodeIfPresent([String: String].self, forKey: .headers)
        expiresAt = try container.decodeFlexibleStringIfPresent(forKey: .expiresAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fileId, forKey: .fileId)
        try container.encode(uploadUrl, forKey: .uploadUrl)
        try container.encode(uploadMethod, forKey: .uploadMethod)
        try container.encodeIfPresent(headers, forKey: .headers)
        try container.encodeIfPresent(expiresAt, forKey: .expiresAt)
    }

    public init(
        fileId: String,
        uploadUrl: String,
        uploadMethod: String,
        headers: [String: String]?,
        expiresAt: String?
    ) {
        self.fileId = fileId
        self.uploadUrl = uploadUrl
        self.uploadMethod = uploadMethod
        self.headers = headers
        self.expiresAt = expiresAt
    }
}

// MARK: - File Category

/// 서버 파일 저장소 카테고리
public enum StorageFileCategory: String, Codable {
    case profileImage = "PROFILE_IMAGE"
    case postImage = "POST_IMAGE"
    case postAttachment = "POST_ATTACHMENT"
    case noticeAttachment = "NOTICE_ATTACHMENT"
    case workbookSubmission = "WORKBOOK_SUBMISSION"
    case schoolLogo = "SCHOOL_LOGO"
    case portfolio = "PORTFOLIO"
    case etc = "ETC"
}
