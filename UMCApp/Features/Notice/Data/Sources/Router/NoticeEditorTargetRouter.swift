//
//  NoticeEditorTargetRouter.swift
//  NoticeData
//
//  Created by 이예지 on 5/17/26.
//

import Foundation
import Moya
import CoreNetwork

/// 공지 에디터 타겟(지부/학교) 목록 조회용 API 라우터
public enum NoticeEditorTargetRouter: BaseTargetType {

    // MARK: - Case

    /// 전체 지부 목록 조회
    case getAllChapters
    /// 전체 학교 목록 조회
    case getAllSchools
    /// 기수별 지부 및 소속 학교 목록 조회
    case getChaptersWithSchools(gisuId: String)
    /// 지부 단건 조회
    case getChapter(chapterId: String)

    // MARK: - BaseTargetType

    /// API 경로
    public var path: String {
        switch self {
        case .getAllChapters:
            return "/api/v1/chapters"
        case .getAllSchools:
            return "/api/v1/schools/all"
        case .getChaptersWithSchools:
            return "/api/v1/chapters/with-schools"
        case .getChapter(let chapterId):
            return "/api/v1/chapters/\(chapterId)"
        }
    }

    /// HTTP 메서드
    public var method: Moya.Method {
        switch self {
        case .getAllChapters, .getAllSchools, .getChaptersWithSchools, .getChapter:
            return .get
        }
    }

    /// 요청 파라미터 구성
    public var task: Task {
        switch self {
        case .getAllChapters, .getAllSchools:
            return .requestPlain
        case .getChaptersWithSchools(let gisuId):
            return .requestParameters(
                parameters: ChaptersWithSchoolsQuery(gisuId: gisuId).toParameters,
                encoding: URLEncoding.queryString
            )
        case .getChapter:
            return .requestPlain
        }
    }
}
