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
