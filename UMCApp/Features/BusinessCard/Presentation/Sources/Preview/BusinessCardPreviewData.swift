//
//  BusinessCardPreviewData.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

#if DEBUG
import BusinessCardDomain
import Foundation
import UMCFoundation

/// 명함 화면·컴포넌트 `#Preview` 가 공유하는 시드 데이터.
///
/// 프리뷰 전용이라 파일 전체를 `#if DEBUG` 로 가드한다 — 앱 실행 시 명함첩은 진짜
/// 빈 상태여야 하므로 런타임 코드에서는 이 타입을 참조하지 않는다.
public enum BusinessCardPreviewData {

    // MARK: - 고정값

    /// 프리뷰 기준 시각 (2026-08-11 11:00 KST). 교환 시각 표시를 결정론적으로 만든다.
    public static let referenceDate = Date(timeIntervalSince1970: 1_786_413_600)

    // MARK: - My Card

    /// 명함_l(``BusinessCardFaceView``)·명함_m(``BusinessCardSummaryView``) 프리뷰가
    /// 공유하는 「내 카드」 한 장. 뒷면 링크 3종(github·linkedIn·blog)을 모두 채워
    /// 뒷면 프리뷰도 같은 값으로 렌더된다.
    public static let myCard = MyCard(
        memberId: "42",
        name: "김유엠",
        nickname: "유엠디",
        part: .front(type: .ios),
        generation: "12",
        university: "한양대학교",
        email: "umc@example.com",
        github: "github.com/umc",
        linkedIn: "linkedin.com/in/umc",
        blog: "umc.blog",
        avatarURL: nil
    )

    // MARK: - Received Cards

    /// 파트 7종(`UMCPartType.allCases`)에 운영진(`.admin`)과 우리가 못 읽은 파트까지
    /// 모두 나오는 명함첩 시드.
    ///
    /// `.admin`은 associated value 제약으로 `allCases` 밖에 있지만 「파트 없는 운영진」
    /// 이라는 실제 역할이다 — 빼면 admin 배지 렌더 경로가 프리뷰에 전혀 나오지 않는다.
    /// 못 읽은 파트도 `part` 가 `.admin` 으로 떨어지므로 두 장을 나란히 두어 인디고와
    /// 회색 폴백이 한 화면에서 비교되게 한다 (#1236).
    public static let receivedCards: [ReceivedCard] = zip(UMCPartType.allCases, identities)
        .enumerated()
        .map { index, pair in
            let (part, identity) = pair
            return ReceivedCard(
                id: part.apiValue,
                profile: MyCard(
                    memberId: part.apiValue,
                    name: identity.name,
                    nickname: identity.nickname,
                    part: part,
                    generation: identity.generation,
                    university: identity.university,
                    email: nil,
                    github: nil,
                    linkedIn: nil,
                    blog: nil,
                    avatarURL: nil
                ),
                exchangedAt: referenceDate.addingTimeInterval(TimeInterval(-index) * 3_600),
                exchangeContext: index == .zero ? "OT에서 교환" : nil
            )
        }
        + [adminReceivedCard, unresolvedPartReceivedCard]

    /// 단건 프리뷰(교환 완료 화면 등)가 대표로 쓰는 한 장.
    public static var receivedCard: ReceivedCard {
        receivedCards[0]
    }

    // MARK: - Private

    /// 운영진(파트 없음) 명함. `exchangedAt`은 파트 7장(-0h…-6h)에 이어 -7h.
    private static let adminReceivedCard = ReceivedCard(
        id: UMCPartType.admin.apiValue,
        profile: MyCard(
            memberId: UMCPartType.admin.apiValue,
            name: "서지우",
            nickname: "지우",
            part: .admin,
            generation: "8",
            university: "세종대학교",
            email: nil,
            github: nil,
            linkedIn: nil,
            blog: nil,
            avatarURL: nil
        ),
        exchangedAt: referenceDate.addingTimeInterval(-7 * 3_600),
        exchangeContext: nil
    )

    /// 우리가 못 읽은 파트를 보내온 상대. `part` 는 관례대로 `.admin` 이지만 `partRaw` 가
    /// 있어 이름·색이 폴백 경로로 간다 — 위 `adminReceivedCard`(진짜 운영진, 인디고)와
    /// 나란히 두면 두 경로가 한눈에 갈린다.
    private static let unresolvedPartReceivedCard = ReceivedCard(
        id: "unresolved",
        profile: MyCard(
            memberId: "unresolved",
            name: "임채원",
            nickname: "채원",
            part: .admin,
            generation: "12",
            university: "성균관대학교",
            email: nil,
            github: nil,
            linkedIn: nil,
            blog: nil,
            avatarURL: nil,
            partRaw: "RUST"
        ),
        exchangedAt: referenceDate.addingTimeInterval(-8 * 3_600),
        exchangeContext: nil
    )

    /// `name`/`nickname`/`university`/`generation` 더미 묶음.
    private struct Identity {
        let name: String
        let nickname: String
        let university: String
        let generation: String
    }

    /// `UMCPartType.allCases` 선언 순서(PM → Design → Server·Spring → Server·Node →
    /// Front·Web → Front·Android → Front·iOS)와 1:1 대응하는 더미 신원. 실명·실기관이
    /// 아니다.
    private static let identities: [Identity] = [
        Identity(name: "김도윤", nickname: "도윤", university: "한성대학교", generation: "10"),
        Identity(name: "이서연", nickname: "서연", university: "중앙대학교", generation: "11"),
        Identity(name: "박현우", nickname: "현우", university: "한양대학교", generation: "9"),
        Identity(name: "최지안", nickname: "지안", university: "홍익대학교", generation: "12"),
        Identity(name: "정하은", nickname: "하은", university: "국민대학교", generation: "10"),
        Identity(name: "강민준", nickname: "민준", university: "동국대학교", generation: "11"),
        Identity(name: "윤소민", nickname: "소민", university: "숭실대학교", generation: "9"),
    ]
}
#endif
