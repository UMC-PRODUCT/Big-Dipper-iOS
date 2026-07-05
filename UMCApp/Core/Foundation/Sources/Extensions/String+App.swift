//
//  String+App.swift
//  UMCFoundation
//
//  Created by euijjang97 on 7/5/26.
//
//  앱 전역에서 재사용하는 순수 Foundation String 유틸리티.
//  UI 프레임워크에 의존하지 않는 검증/포매팅 헬퍼만 둡니다.
//

import Foundation

public extension String {

    // MARK: - Validation

    /// 유효한 http/https 절대 URL 문자열인지 여부.
    ///
    /// 스킴이 `http`/`https`이고 host가 존재하는 경우에만 `true`를 반환합니다.
    var isValidHTTPURL: Bool {
        guard let url = URL(string: self),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host(),
              host.isEmpty == false else {
            return false
        }
        return true
    }

    // MARK: - Formatting

    /// 문자 단위 줄바꿈을 강제하기 위해 각 문자 사이에 zero-width space를 삽입한 문자열.
    ///
    /// 긴 식별자·URL처럼 단어 경계가 없는 문자열이 컨테이너를 벗어나지 않도록
    /// 텍스트 렌더링 시 문자 단위 wrapping을 유도할 때 사용합니다.
    var forceCharWrapping: String {
        map(String.init).joined(separator: "\u{200B}")
    }
}
