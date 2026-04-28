import Foundation
import Moya

enum AuthRouter: BaseTargetType {
    /// 로그인
    case login(body: LoginBody)

    var path: String {
        switch self {
        case .login: return "/auth/login"
        }
    }

    var method: Moya.Method {
        switch self {
        case .login: return .post
        }
    }
}
