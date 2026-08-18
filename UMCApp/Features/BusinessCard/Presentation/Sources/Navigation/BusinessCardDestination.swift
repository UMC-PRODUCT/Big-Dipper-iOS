//
//  BusinessCardDestination.swift
//  BusinessCardPresentation
//
//  Created by One on 8/17/26.
//

/// 명함 화면 목적지.
///
/// 명함 화면들은 **마이페이지 탭 스택 위에** 쌓이지만 MyPage 모듈이 소유하지 않는다.
/// 소유하게 하면 MyPagePresentation → BusinessCardPresentation 이라는 Feature 간 의존이
/// 생기는데, 이 레포는 그걸 만들지 않고 App 셸이 중개한다
/// (선례: `NavigationRoutingView` 가 `ActivityDestination` 을 직접 만들어 넣는다).
///
/// 그래서 ``MyPageDestination`` 과 달리 `public` 이다 — App 셸이 이 값을 만들고
/// 등록까지 맡는다.
public enum BusinessCardDestination: Hashable {

    /// 명함첩 — 받은 명함 그리드 (MP-F05).
    case receivedCards

    /// 내 명함 QR (MP-F04).
    case cardQR

    /// 근거리 명함 교환 세션 (MP-F06).
    case exchange
}
