//
//  StorageUploadDTO.swift
//  UMCFoundation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation

// MARK: - Prepare Upload Request

/// 파일 업로드 준비 요청 DTO (Presigned URL 발급용)
public struct StoragePrepareUploadRequestDTO: Codable {
    public let fileName: String
    public let contentType: String
    public let fileSize: Int
    public let category: StorageFileCategory
    
    public init(fileName: String, contentType: String, fileSize: Int, category: StorageFileCategory) {
        self.fileName = fileName
        self.contentType = contentType
        self.fileSize = fileSize
        self.category = category
    }
}

// MARK: - Prepare Upload Response

/// 파일 업로드 준비 응답 DTO (Presigned URL + 헤더 포함)
public struct StoragePrepareUploadResponseDTO: Codable {
    public let fileId: String
    public let uploadUrl: String
    public let uploadMethod: String
    public let headers: [String: String]?
    public let expiresAt: String?
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
