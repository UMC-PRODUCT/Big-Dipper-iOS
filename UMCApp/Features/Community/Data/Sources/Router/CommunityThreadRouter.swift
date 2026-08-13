//
//  CommunityThreadRouter.swift
//  CommunityData
//

import Foundation
import Moya
import CoreNetwork

/// 커뮤니티 스레드 REST 엔드포인트.
///
/// 메시지 생성·수정·삭제·리액션·읽음은 STOMP 전용이라 여기 없다. 신고는 예외로 REST 다 —
/// 다른 참여자에게 방송되지 않는 접수 요청이라 실시간 채널을 탈 이유가 없다.
public enum CommunityThreadRouter {
    case getThreads(query: ThreadListQuery)
    case getThread(threadId: String)
    case createThread(body: CreateThreadBody)
    /// 부분 수정. 본문에 실린 키만 갱신된다 (`UpdateThreadBody` 주석).
    case updateThread(threadId: String, body: UpdateThreadBody)
    case deleteThread(threadId: String)
    case getMessages(threadId: String, query: ThreadMessageQuery)
    case setPin(threadId: String, isPinned: Bool)
    case setMute(threadId: String, isMuted: Bool)
    case getMembers(threadId: String)
    case kickMember(threadId: String, memberId: String)
    case changeMemberRole(threadId: String, memberId: String, body: ThreadMemberRoleBody)
    case leave(threadId: String)
    case reportMessage(messageId: String, body: ReportMessageBody)
}

extension CommunityThreadRouter: BaseTargetType {

    private var threadsPath: String { "/api/v1/community/threads" }
    /// 신고만 `/threads` 하위가 아니라 메시지 단독 경로를 쓴다 (서버 계약).
    private var messagesPath: String { "/api/v1/community/messages" }

    private func membersPath(_ threadId: String) -> String {
        "\(threadsPath)/\(threadId)/members"
    }

    public var path: String {
        switch self {
        case .getThreads, .createThread:
            return threadsPath
        case .getThread(let threadId),
             .updateThread(let threadId, _),
             .deleteThread(let threadId):
            return "\(threadsPath)/\(threadId)"
        case .getMessages(let threadId, _):
            return "\(threadsPath)/\(threadId)/messages"
        case .setPin(let threadId, _):
            return "\(threadsPath)/\(threadId)/pin"
        case .setMute(let threadId, _):
            return "\(threadsPath)/\(threadId)/mute"
        case .getMembers(let threadId):
            return membersPath(threadId)
        case .kickMember(let threadId, let memberId):
            return "\(membersPath(threadId))/\(memberId)"
        case .changeMemberRole(let threadId, let memberId, _):
            return "\(membersPath(threadId))/\(memberId)/role"
        case .leave(let threadId):
            return "\(threadsPath)/\(threadId)/leave"
        case .reportMessage(let messageId, _):
            return "\(messagesPath)/\(messageId)/report"
        }
    }

    public var method: Moya.Method {
        switch self {
        case .getThreads, .getThread, .getMessages, .getMembers:
            return .get
        case .setPin(_, let isPinned):
            return isPinned ? .post : .delete
        case .setMute(_, let isMuted):
            return isMuted ? .post : .delete
        case .kickMember, .deleteThread:
            return .delete
        case .changeMemberRole, .updateThread:
            return .patch
        case .createThread, .leave, .reportMessage:
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
        case .createThread(let body):
            return .requestJSONEncodable(body)
        case .updateThread(_, let body):
            return .requestJSONEncodable(body)
        case .changeMemberRole(_, _, let body):
            return .requestJSONEncodable(body)
        case .reportMessage(_, let body):
            return .requestJSONEncodable(body)
        case .getThread, .deleteThread, .setPin, .setMute,
             .getMembers, .kickMember, .leave:
            return .requestPlain
        }
    }
}
