//
//  MyPageFeatureView.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 3/6/26.
//

import CoreDI
import SwiftUI

/// MyPage 탭의 공개 진입점.
///
/// 탭 셸이 이 타입만 알면 되도록 DI 컨테이너·에러 핸들러 확보를 여기서 끝내고,
/// 실제 화면 조립은 모듈 내부의 ``MyPageView``가 맡는다.
public struct MyPageFeatureView: View {

    // MARK: - Property

    @Environment(\.di) private var di

    // MARK: - Init

    public init() {}

    // MARK: - Body

    public var body: some View {
        MyPageView(container: di)
    }
}
