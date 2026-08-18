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

    /// 파트 7종(`UMCPartType.allCases`)이 모두 나오는 명함첩 시드.
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

    /// 단건 프리뷰(교환 완료 화면 등)가 대표로 쓰는 한 장.
    public static var receivedCard: ReceivedCard {
        receivedCards[0]
    }

    // MARK: - Private

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
