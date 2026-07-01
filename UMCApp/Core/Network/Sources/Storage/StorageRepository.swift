//
//  StorageRepository.swift
//  UMCFoundation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import UMCFoundation

/// 파일 저장소 Repository 구현체
///
/// Presigned URL 발급 → 외부 URL 업로드 → 완료 확인 3단계 플로우를 처리합니다.
public final class StorageRepository: StorageRepositoryProtocol, @unchecked Sendable {

    // MARK: - Property

    private let adapter: MoyaNetworkAdapter
    private let session: URLSession
    private let decoder: JSONDecoder

    // MARK: - Init

    public init(
        adapter: MoyaNetworkAdapter,
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.adapter = adapter
        self.session = session
        self.decoder = decoder
    }

    // MARK: - Function

    /// 파일 업로드를 준비하고 Presigned URL을 발급받습니다.
    public func prepareUpload(
        fileName: String,
        contentType: String,
        fileSize: Int,
        category: StorageFileCategory
    ) async throws -> StoragePrepareUploadResponseDTO {
        let request = StoragePrepareUploadRequestDTO(
            fileName: fileName,
            contentType: contentType,
            fileSize: fileSize,
            category: category
        )

        let response = try await adapter.request(
            StorageRouter.prepareUpload(request: request)
        )
        let apiResponse = try decoder.decode(
            APIResponse<StoragePrepareUploadResponseDTO>.self,
            from: response.data
        )
        return try apiResponse.unwrap()
    }

    /// Presigned URL로 파일 바이너리를 직접 업로드합니다.
    ///
    /// - Note: 서버 API가 아닌 외부 스토리지(S3 등)에 직접 업로드하므로 URLSession을 사용합니다.
    public func uploadFile(
        to url: String,
        data: Data,
        method: String,
        headers: [String: String]?,
        contentType: String?
    ) async throws {
        guard let urlObject = URL(string: url) else {
            throw RepositoryError.decodingError(detail: "invalid uploadUrl")
        }

        var request = URLRequest(url: urlObject)
        request.httpMethod = method.uppercased()

        if let headers = headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue(contentType ?? "application/octet-stream", forHTTPHeaderField: "Content-Type")
        }

        let response: URLResponse
        do {
            (_, response) = try await session.upload(for: request, from: data)
        } catch let urlError as URLError where urlError.code != .cancelled {
            throw NetworkError.from(urlError: urlError)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.requestFailed(statusCode: httpResponse.statusCode, data: nil)
        }
    }

    public func confirmUpload(fileId: String) async throws {
        let response = try await adapter.request(
            StorageRouter.confirmUpload(fileId: fileId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
    }

    public func deleteFile(fileId: String) async throws {
        let response = try await adapter.request(
            StorageRouter.deleteFile(fileId: fileId)
        )
        let apiResponse = try decoder.decode(
            APIResponse<EmptyResult>.self,
            from: response.data
        )
        _ = try apiResponse.unwrap()
    }
}
