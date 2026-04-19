//
//  NoticeEditorSubCategorySection.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI

struct NoticeEditorSubCategorySection: View {

    // MARK: - Property

    let subCategories: [EditorSubCategory]
    let showsExclusivityHint: Bool
    let isHighlighted: (EditorSubCategory) -> Bool
    let onTap: (EditorSubCategory) -> Void

    // MARK: - Constants

    private enum Constants {
        static let chipSpacing: CGFloat = 8
    }

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing12) {
            HStack(alignment: .center) {
                Text("공지 대상 선택")
                    .appFont(.calloutEmphasis)

                if showsExclusivityHint {
                    Text("지부와 학교는 동시에 선택할 수 없습니다.")
                        .appFont(.footnote, color: .grey400)
                }
            }

            HStack(spacing: Constants.chipSpacing) {
                ForEach(subCategories) { subCategory in
                    ChipButton(
                        subCategory.labelText,
                        isSelected: isHighlighted(subCategory),
                        trailingIcon: subCategory.hasFilter ? true : nil
                    ) {
                        onTap(subCategory)
                    }
                    .buttonSize(.medium)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
    }
}
