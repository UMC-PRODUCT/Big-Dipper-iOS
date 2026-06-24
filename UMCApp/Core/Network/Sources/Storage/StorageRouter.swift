//
//  StorageRouter.swift
//  UMCFoundation
//
//  Created by 이예지 on 5/30/26.
//

import Foundation
import UMCFoundation
import Moya

/// 파일 저장소 API 라우터 (Presigned URL 기반 업로드/삭제)
public enum StorageRouter: BaseTargetType {
    /// 업로드 준비 (Presigned URL 발급)
    case prepareUpload(request: StoragePrepareUploadRequestDTO)
    /// 업로드 완료 확인
    case confirmUpload(fileId: String)
    /// 파일 삭제
    case deleteFile(fileId: String)

    public var path: String {
        switch self {
        case .prepareUpload:
            return "/api/v1/storage/prepare-upload"
        case .confirmUpload(let fileId):
            return "/api/v1/storage/\(fileId)/confirm"
        case .deleteFile(let fileId):
            return "/api/v1/storage/\(fileId)"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .prepareUpload, .confirmUpload:
            return .post
        case .deleteFile:
            return .delete
        }
    }

    public var task: Task {
        switch self {
        case .prepareUpload(let request):
            return .requestJSONEncodable(request)
        case .confirmUpload, .deleteFile:
            return .requestPlain
        }
    }
}
