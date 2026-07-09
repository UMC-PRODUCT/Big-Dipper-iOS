import CoreNetwork
import Foundation
import Moya

/// Home 관련 API 엔드포인트 정의.
///
/// - Note: `getGisuDetail`은 이슈 문구("profile/getGen")에 명시된 범위를 살짝 넘어서지만,
///   시즌 카드의 "누적 활동일"을 실제 값으로 계산하려면 기수 시작일이 필요해 추가했다.
public enum HomeRouter: BaseTargetType {

    // MARK: - Cases

    /// 내 프로필 조회 (시즌/세대 카드 구성용)
    case getGen
    /// 기수 상세 조회 (시즌 카드의 활동일 계산용 시작일 조회)
    case getGisuDetail(gisuId: String)

    // MARK: - Path

    public var path: String {
        switch self {
        case .getGen:
            return "/api/v1/member/me"
        case .getGisuDetail(let gisuId):
            return "/api/v1/gisu/\(gisuId)"
        }
    }

    // MARK: - Method

    public var method: Moya.Method {
        switch self {
        case .getGen, .getGisuDetail:
            return .get
        }
    }

    // MARK: - Task

    public var task: Moya.Task {
        switch self {
        case .getGen, .getGisuDetail:
            return .requestPlain
        }
    }
}
