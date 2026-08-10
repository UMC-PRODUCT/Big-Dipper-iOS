//
//  MyPageDestination.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

/// MyPage 탭 안에서 push 되는 화면 목적지.
///
/// 목적지를 App 의 공용 enum 이 아니라 이 모듈이 소유한다 — ``ActivityDestination`` 과 같은 이유로,
/// 공용 enum 은 연관값 때문에 Core → Feature 역방향 의존을 만든다. `CoreRouting.PathStore` 가
/// 타입 소거 경로를 쓰므로 Feature 가 자기 목적지를 들고도 같은 탭 스택에 실린다.
/// 등록까지 탭 루트(``MyPageView``)가 맡으므로 목적지도 화면도 `public` 으로 열 필요가 없다.
enum MyPageDestination: Hashable {

    /// 내 활동 게시글 목록 (내가 쓴 글 / 댓글 단 글 / 스크랩).
    ///
    /// - Parameter logType: 진입 시 처음 보여줄 활동 종류. 화면 안에서 세 종류를 전환할 수 있다.
    case myActivePosts(logType: MyActiveLogsType)
}
