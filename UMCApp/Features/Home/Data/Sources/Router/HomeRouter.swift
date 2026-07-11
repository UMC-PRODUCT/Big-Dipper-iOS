import CoreNetwork
import Foundation
import Moya

/// Home 관련 API 엔드포인트 정의.
///
/// - Note: 내 프로필 조회는 정본 파이프라인(`CoreDomain.MemberProfileRepositoryProtocol` →
///   `CoreNetwork.MemberProfileRouter.getMyProfile`)으로 이관되어 이 라우터에서는 제거됐다.
///   `getGisuDetail`은 시즌 카드의 "누적 활동일"을 실제 값으로 계산하려면 기수 시작일이
///   필요해 유지한다.
public enum HomeRouter: BaseTargetType {

    // MARK: - Cases

    /// 기수 상세 조회 (시즌 카드의 활동일 계산용 시작일 조회)
    case getGisuDetail(gisuId: String)

    // MARK: - Path

    public var path: String {
        switch self {
        case .getGisuDetail(let gisuId):
            return "/api/v1/gisu/\(gisuId)"
        }
    }

    // MARK: - Method

    public var method: Moya.Method {
        switch self {
        case .getGisuDetail:
            return .get
        }
    }

    // MARK: - Task

    public var task: Moya.Task {
        switch self {
        case .getGisuDetail:
            return .requestPlain
        }
    }
}
