//
//  NameAndNickname.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import SwiftUI

/// 실명과 닉네임을 각각 읽기 전용 섹션으로 보여준다.
struct NameAndNickname: View, Equatable {

    // MARK: - Property

    private let name: String
    private let nickname: String

    private enum Constants {
        static let nameHeader = "이름"
        static let nicknameHeader = "닉네임"
    }

    // MARK: - Init

    init(name: String, nickname: String) {
        self.name = name
        self.nickname = nickname
    }

    // MARK: - Body

    var body: some View {
        Group {
            ReadOnlyTextField(placeholder: name, header: Constants.nameHeader)
            ReadOnlyTextField(placeholder: nickname, header: Constants.nicknameHeader)
        }
    }
}
