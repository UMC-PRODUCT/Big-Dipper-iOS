//
//  StorageRepositoryProtocol.swift
//  UMCFoundation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation

/// 파일 저장소 Repository 인터페이스
///
/// Presigned URL 기반 파일 업로드(prepare → upload → confirm) 및 삭제를 정의합니다.
public protocol StorageRepositoryProtocol: Sendable {
    /// Presigned URL 발급 요청
    func prepareUpload(
        fileName: String,
        contentType: String,
        fileSize: Int,
        category: StorageFileCategory
    ) async throws -> StoragePrepareUploadResponseDTO

    /// Presigned URL로 파일 업로드
    func uploadFile(
        to url: String,
        data: Data,
        method: String,
        headers: [String: String]?,
        contentType: String?
    ) async throws

    /// 업로드 완료 확인
    func confirmUpload(fileId: String) async throws

    /// 파일 삭제
    func deleteFile(fileId: String) async throws
}
