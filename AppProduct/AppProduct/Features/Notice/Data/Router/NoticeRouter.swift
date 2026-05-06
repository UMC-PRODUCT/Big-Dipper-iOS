//
//  NoticeRouter.swift
//  AppProduct
//
//  Created by 이예지 on 2/11/26.
//

import Foundation
import Moya
internal import Alamofire

// get post put patch delete
/// Notice 관련 API 엔드포인트 정의
enum NoticeRouter: BaseTargetType {
    
    // MARK: - Cases
    
    
    /// 공지사항 전체 조회
    case getAllNotices(request: NoticeListRequestDTO)
    /// 공지사항 상세 조회
    case getDetailNotice(noticeId: Int)
    /// 공지 열람 현황 통계 조회 (수치)
    case getNoticeReadStatusCount(noticeId: Int)
    /// 공지 열람 현황 상세 조회 (사용자 리스트)
    case getNoticeReadStatusList(
        noticeId: Int,
        cursorId: Int,
        filterType: String,
        organizationIds: [Int],
        status: String
    )
    /// 공지사항 검색
    case searchNotice(
        keyword: String,
        request: NoticeListRequestDTO
    )
    
    // POST Method
    /// 공지사항 생성
    case postNotice(body: PostNoticeRequestDTO)
    /// 공지사항 투표 추가
    case addVote(
        noticeId: Int,
        body: AddVoteRequestDTO
    )
    /// 공지사항 링크 추가
    case addLink(
        noticeId: Int,
        links: [String]
    )
    /// 공지사항 이미지 추가
    case addImage(
        noticeId: Int,
        imageIds: [String]
    )
    /// 공지사항 리마인더 발송
    case sendReminder(
        noticeId: Int,
        targetIds: [Int]
    )
    /// 공지사항 읽음 처리
    case readNotice(noticeId: Int)
    /// 투표 응답(사용자 선택 전송)
    case submitVoteResponse(
        noticeId: Int,
        optionIds: [Int]
    )
    /// 투표 응답 수정
    case updateVoteResponse(
        noticeId: Int,
        optionIds: [Int]
    )
    
    // PATCH Method
    /// 공지사항 수정
    case updateNotice(
        noticeId: Int,
        body: UpdateNoticeRequestDTO
    )
    /// 공지사항 링크 수정
    case updateLink(
        noticeId: Int,
        links: [String]
    )
    /// 공지사항 이미지 수정
    case updateImage(
        noticeId: Int,
        imageIds: [String]
    )
    
    // DELETE Method
    /// 공지사항 삭제
    case deleteNotice(noticeId: Int)
    /// 공지사항 연결 투표 삭제
    case deleteVote(noticeId: Int)
    
    // MARK: - Path

    /// 각 케이스에 대응하는 API 엔드포인트 경로
    var path: String {
        switch self {
        case .getAllNotices:
            return "/api/v1/notices"
        case .getDetailNotice(let noticeId):
            return "/api/v1/notices/\(noticeId)"
        case .getNoticeReadStatusCount(let noticeId):
            return "/api/v1/notices/\(noticeId)/read-statics"
        case .getNoticeReadStatusList(let noticeId, _, _, _, _):
            return "/api/v1/notices/\(noticeId)/read-status"
        case .searchNotice:
            return "/api/v1/notices/search"
        case .postNotice:
            return "/api/v1/notices"
        case .addVote(let noticeId, _):
            return "/api/v1/notices/\(noticeId)/votes"
        case .addLink(let noticeId, _):
            return "/api/v1/notices/\(noticeId)/links"
        case .addImage(let noticeId, _):
            return "/api/v1/notices/\(noticeId)/images"
        case .sendReminder(let noticeId, _):
            return "/api/v1/notices/\(noticeId)/reminders"
        case .readNotice(let noticeId):
            return "/api/v1/notices/\(noticeId)/read"
        case .submitVoteResponse(let noticeId, _):
            return "/api/v1/notices/\(noticeId)/votes/responses"
        case .updateVoteResponse(let noticeId, _):
            return "/api/v1/notices/\(noticeId)/votes/responses"
        case .updateNotice(let noticeId, _):
            return "/api/v1/notices/\(noticeId)"
        case .updateLink(let noticeId, _):
            return "/api/v1/notices/\(noticeId)/links"
        case .updateImage(let noticeId, _):
            return "/api/v1/notices/\(noticeId)/images"
        case .deleteNotice(let noticeId):
            return "/api/v1/notices/\(noticeId)"
        case .deleteVote(let noticeId):
            return "/api/v1/notices/\(noticeId)/vote"
        }
    }
    
    // MARK: - Method

    /// 각 케이스에 대응하는 HTTP 메서드
    var method: Moya.Method {
        switch self {
        case .getAllNotices, .getDetailNotice, .getNoticeReadStatusCount, .getNoticeReadStatusList, .searchNotice:
            return .get
        case .postNotice, .addVote, .addLink, .addImage, .sendReminder, .readNotice, .submitVoteResponse:
            return .post
        case .updateVoteResponse:
            return .put
        case .updateNotice, .updateLink, .updateImage:
            return .patch
        case .deleteNotice, .deleteVote:
            return .delete
        }
    }
    
    // MARK: - Task

    /// 각 케이스에 대응하는 요청 파라미터 및 인코딩 방식
    var task: Moya.Task {
        switch self {
        case .getAllNotices(let request):
            return .requestParameters(
                parameters: request.queryItems,
                encoding: URLEncoding.queryString
            )
        case .getDetailNotice:
            return .requestPlain
        case .getNoticeReadStatusCount:
            return .requestPlain
        case .getNoticeReadStatusList(
            _,
            let cursorId,
            let filterType,
            let organizationIds,
            let status
        ):
            return .requestParameters(
                parameters: [
                    "cursorId": cursorId,
                    "filterType": filterType,
                    "organizationIds": organizationIds,
                    "status": status
                ],
                encoding: URLEncoding.queryString
            )
        case .searchNotice(let keyword, let request):
            var params = request.queryItems
            params["keyword"] = keyword
            return .requestParameters(
                parameters: params,
                encoding: URLEncoding.queryString
            )
        case .postNotice(let body):
            return .requestJSONEncodable(body)
        case .addVote(_, let body):
            return .requestJSONEncodable(body)
        case .addLink(_, let links):
            return .requestParameters(
                parameters: ["links": links],
                encoding: JSONEncoding.default
            )
        case .addImage(_, let imageIds):
            return .requestParameters(
                parameters: ["imageIds": imageIds],
                encoding: JSONEncoding.default
            )
        case .sendReminder(_, let targetIds):
            return .requestParameters(
                parameters: ["targetIds": targetIds],
                encoding: JSONEncoding.default
            )
        case .readNotice:
            return .requestPlain
        case .submitVoteResponse(_, let optionIds):
            return .requestParameters(
                parameters: ["optionIds": optionIds],
                encoding: JSONEncoding.default
            )
        case .updateVoteResponse(_, let optionIds):
            return .requestParameters(
                parameters: ["optionIds": optionIds],
                encoding: JSONEncoding.default
            )
        case .updateNotice(_, let body):
            return .requestJSONEncodable(body)
        case .updateLink(_, let links):
            return .requestParameters(
                parameters: ["links": links],
                encoding: JSONEncoding.default
            )
        case .updateImage(_, let imageIds):
            return .requestParameters(
                parameters: ["imageIds": imageIds],
                encoding: JSONEncoding.default
            )
        case .deleteNotice, .deleteVote:
            return .requestPlain
        }
    }
}
