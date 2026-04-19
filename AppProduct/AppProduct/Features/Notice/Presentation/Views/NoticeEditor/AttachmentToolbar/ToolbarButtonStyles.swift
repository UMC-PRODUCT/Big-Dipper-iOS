//
//  ToolbarButtonStyles.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

// MARK: - Constants

fileprivate enum ToolbarButtonConstants {
    static let iconSize: CGFloat = 20
    static let frame: CGSize = .init(width: 30, height: 30)
}

// MARK: - ToolbarIconButton

/// 에디터 첨부 툴바에서 사용하는 공용 아이콘 버튼입니다.
struct ToolbarIconButton: View {

    // MARK: - Property

    let icon: String
    var tint: Color = .black
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: ToolbarButtonConstants.iconSize))
                .foregroundStyle(tint)
                .frame(
                    width: ToolbarButtonConstants.frame.width,
                    height: ToolbarButtonConstants.frame.height
                )
                .padding(DefaultConstant.defaultBtnPadding)
        }
    }
}

// MARK: - ToolbarTextFormatButton

/// 인라인 서식 텍스트 버튼 (B/I/U/S)입니다. 활성 여부에 따라 실제 서식 미리보기를 적용합니다.
struct ToolbarTextFormatButton: View {

    // MARK: - Property

    let title: String
    var weight: Font.Weight = .regular
    var isItalic: Bool = false
    var isUnderline: Bool = false
    var isStrikethrough: Bool = false
    let isActive: Bool
    let action: () -> Void

    // MARK: - Body

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: ToolbarButtonConstants.iconSize, weight: weight).italic(isItalic))
                .underline(isUnderline)
                .strikethrough(isStrikethrough)
                .foregroundStyle(isActive ? Color.indigo500 : .black)
                .frame(
                    width: ToolbarButtonConstants.frame.width,
                    height: ToolbarButtonConstants.frame.height
                )
                .padding(DefaultConstant.defaultBtnPadding)
        }
    }
}
