import Foundation
import Moya

enum NoticeRouter: BaseTargetType {
    /// 공지 전체 조회
    case getAllNotices
    /// 공지 상세
    case getDetailNotice(id: Int)
    /// 공지 생성
    case postNotice(body: PostNoticeBody)

    var path: String {
        switch self {
        case .getAllNotices: return "/notices"
        case .getDetailNotice(let id): return "/notices/\(id)"
        case .postNotice: return "/notices"
        }
    }

    var method: Moya.Method {
        switch self {
        case .getAllNotices: return .get
        case .getDetailNotice: return .get
        case .postNotice: return .post
        }
    }
}
