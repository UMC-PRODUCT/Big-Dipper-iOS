//
//  BusinessCardDebugDestination.swift
//  UMCApp
//
//  Created by One on 8/16/26.
//

#if DEBUG
/// 명함 검증 화면 목적지. 제품 목적지와 섞이지 않도록 별도 타입으로 둔다
/// (`PathStore`가 타입 소거라 같은 탭 스택에 그대로 실린다).
enum BusinessCardDebugDestination: Hashable {
    case harness
}
#endif
