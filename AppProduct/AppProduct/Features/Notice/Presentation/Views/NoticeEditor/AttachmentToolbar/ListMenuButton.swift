//
//  ListMenuButton.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

/// 공지 에디터 첨부 툴바의 목록 스타일 선택 메뉴입니다.
struct ListMenuButton: View {

    // MARK: - Property

    @Bindable var editorToolbarViewModel: EditorToolbarViewModel

    // MARK: - Constants

    private enum Constants {
        static let iconSize: CGFloat = 20
        static let frame: CGSize = .init(width: 30, height: 30)
    }

    // MARK: - Body

    var body: some View {
        Menu {
            Button {
                editorToolbarViewModel.applyList(.bullet)
            } label: {
                Label("구분점", systemImage: "list.bullet")
            }
            Button {
                editorToolbarViewModel.applyList(.dash)
            } label: {
                Label("대시선", systemImage: "list.dash")
            }
            Button {
                editorToolbarViewModel.applyList(.number)
            } label: {
                Label("숫자", systemImage: "list.number")
            }
        } label: {
            Image(systemName: "list.bullet")
                .font(.system(size: Constants.iconSize))
                .foregroundStyle(.black)
                .frame(width: Constants.frame.width, height: Constants.frame.height)
                .padding(DefaultConstant.defaultBtnPadding)
        }
    }
}
