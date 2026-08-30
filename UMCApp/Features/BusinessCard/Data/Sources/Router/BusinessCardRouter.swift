//
//  BusinessCardRouter.swift
//  BusinessCardData
//
//  Created by One on 8/16/26.
//

import Foundation
import Moya
import CoreNetwork

/// 명함·마이페이지 카운트 라우터.
///
/// 스터디·스크랩 엔드포인트는 Activity·MyPage Router에도 있지만, 크로스 피처 import
/// 금지 원칙에 따라 자체 케이스로 복제한다 (선례: `/member/profile/{id}`가
/// MyPageRouter·StudyRouter 양쪽에 존재). path 변경은 각 Router의 계약 테스트가 잡는다.
///
/// - Important: 명함 전용 경로(`/api/v1/cards/**`, `/api/v2/member/me/stats`)는 **서버에
///   아직 존재하지 않는다**(2026-08-30 재확인). 계약을 먼저 못박아 두는 자리이고, 릴리스
///   빌드에서는 호출부가 없다 — `ReceivedCardRepository` 의 원격 의존성이 `nil` 이라
///   `sync()` 가 첫 줄에서 돌아간다.
enum BusinessCardRouter {
    /// **관리 가능한** 스터디 목록 (`GET /api/v1/study-groups/managed`) — 항목 수만 쓴다.
    ///
    /// - Important: `managed` 는 「내가 참여한」이 아니라 「내가 관리할 수 있는」이다
    ///   (서버 `StudyGroupController`·`StudyRouter.getStudyGroupNames` 와 같은 의미).
    ///   그래서 운영진이 아닌 챌린저에게 이 카운트는 항상 0이다. 참여 기준 목록 API가
    ///   서버에 없어 클라이언트에서 메울 수 없다 (#1222).
    case getMyStudyGroups(query: StudyCountQueryDTO)
    /// 스크랩 글 페이지 (`GET /api/v1/posts/scrapped`) — totalElements만 쓴다.
    case getScrappedPosts(query: ScrappedCountQueryDTO)
    /// 상대 프로필 (`GET /api/v1/member/profile/{memberId}`) — QR 딥링크 스캔이 명함을 복원한다.
    ///
    /// MyPageRouter에도 같은 경로가 있지만 그쪽은 `memberId: Int`라 서버 정수를 전 레이어
    /// `String`으로 통일하는 규약에서 벗어나 있다. 복제하는 김에 `String`으로 맞춘다.
    case getMemberProfile(memberId: String)
    /// 마이페이지 통합 카운트 (`GET /api/v2/member/me/stats`).
    ///
    /// v1이 아니라 v2인 이유: `MemberQueryV2Controller` 가 「화면에 필요한 종합 정보」를
    /// 주는 BFF 자리이고, 본인 전용 경로라 `@CheckAccess` 없이 인증 필터로만 보호하는
    /// 정책이 `/me` 와 같다.
    case getMemberStats
    /// 명함첩 전량 동기화 (`GET /api/v1/cards/exchanges`).
    ///
    /// 커서 키는 **불변 `id`** 다. `exchanged_at` 정렬로 페이징하면 재교환 upsert가 행을
    /// 목록 맨 앞으로 점프시켜 스캔이 그 행을 놓치고, 전량 재조정이 「서버에 없다」로
    /// 읽어 멀쩡한 명함을 지운다.
    case getCardExchanges(query: CardExchangePageQueryDTO)
    /// 교환 성립 upsert (`POST /api/v1/cards/exchanges`).
    case createCardExchange(body: CreateCardExchangeRequestDTO)
    /// 내 쪽 교환 행만 삭제 (`DELETE /api/v1/cards/exchanges/{cardMemberId}`).
    case deleteCardExchange(cardMemberId: String)
    /// 명함 전용 공개 응답 (`GET /api/v1/cards/members/{memberId}`).
    ///
    /// 아직 호출부가 없다. `PeerCardRepository` 가 프로필 API에 얹혀 있어 기수·파트가
    /// 보장되지 않는 것이 「운영진 · 0기」 명함(#1223)의 근본 원인이라, 그 전환의 대상이
    /// 될 계약을 먼저 못박는다.
    case getCardByMemberId(memberId: String)
}

extension BusinessCardRouter: BaseTargetType {
    var path: String {
        switch self {
        case .getMyStudyGroups: return "/api/v1/study-groups/managed"
        case .getScrappedPosts: return "/api/v1/posts/scrapped"
        case .getMemberProfile(let memberId): return "/api/v1/member/profile/\(memberId)"
        case .getMemberStats: return "/api/v2/member/me/stats"
        case .getCardExchanges, .createCardExchange: return "/api/v1/cards/exchanges"
        case .deleteCardExchange(let cardMemberId):
            return "/api/v1/cards/exchanges/\(cardMemberId)"
        case .getCardByMemberId(let memberId): return "/api/v1/cards/members/\(memberId)"
        }
    }

    var method: Moya.Method {
        switch self {
        case .createCardExchange: return .post
        case .deleteCardExchange: return .delete
        case .getMyStudyGroups, .getScrappedPosts, .getMemberProfile,
             .getMemberStats, .getCardExchanges, .getCardByMemberId:
            return .get
        }
    }

    var task: Moya.Task {
        switch self {
        case .getMyStudyGroups(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .getScrappedPosts(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .getCardExchanges(let query):
            return .requestParameters(
                parameters: query.toParameters,
                encoding: URLEncoding.queryString
            )
        case .createCardExchange(let body):
            return .requestJSONEncodable(body)
        case .getMemberProfile, .getMemberStats, .deleteCardExchange, .getCardByMemberId:
            return .requestPlain
        }
    }
}
