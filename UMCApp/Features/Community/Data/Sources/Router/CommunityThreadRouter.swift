//
//  CommunityThreadRouter.swift
//  CommunityData
//

import Foundation
import Moya
import CoreNetwork

/// 커뮤니티 스레드 REST 엔드포인트.
///
/// 메시지 생성·수정·삭제·리액션·읽음은 STOMP 전용이라 여기 없다.
public enum CommunityThreadRouter {
    case getThreads(query: ThreadListQuery)
    case getThread(threadId: String)
    case getMessages(threadId: String, query: ThreadMessageQuery)
    case setPin(threadId: String, isPinned: Bool)
    case setMute(threadId: String, isMuted: Bool)
    case leave(threadId: String)
}

extension CommunityThreadRouter: BaseTargetType {

    private var threadsPath: String { "/api/v1/community/threads" }

    public var path: String {
        switch self {
        case .getThreads:
            return threadsPath
        case .getThread(let threadId):
            return "\(threadsPath)/\(threadId)"
        case .getMessages(let threadId, _):
            return "\(threadsPath)/\(threadId)/messages"
        case .setPin(let threadId, _):
            return "\(threadsPath)/\(threadId)/pin"
        case .setMute(let threadId, _):
            return "\(threadsPath)/\(threadId)/mute"
        case .leave(let threadId):
            return "\(threadsPath)/\(threadId)/leave"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .getThreads, .getThread, .getMessages:
            return .get
        case .setPin(_, let isPinned):
            return isPinned ? .post : .delete
        case .setMute(_, let isMuted):
            return isMuted ? .post : .delete
        case .leave:
            return .post
        }
    }

    public var task: Moya.Task {
        switch self {
        case .getThreads(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .getMessages(_, let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .getThread, .setPin, .setMute, .leave:
            return .requestPlain
        }
    }
}
