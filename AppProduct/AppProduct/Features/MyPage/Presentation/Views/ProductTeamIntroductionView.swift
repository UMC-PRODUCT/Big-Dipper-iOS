//
//  ProductTeamIntroductionView.swift
//  AppProduct
//
//  Created by euijjang97 on 3/13/26.
//

import SwiftUI

/// 마이페이지에서 프로덕트 팀 소개 글을 표시하는 화면입니다.
struct ProductTeamIntroductionView: View {
    // MARK: - Property

    private let content = ProductTeamIntroduction.current

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DefaultSpacing.spacing24) {
                ForEach(content.paragraphs, id: \.self) { paragraph in
                    Text(paragraph)
                        .appFont(.body, weight: .regular, color: .grey900)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                    Text(content.teamPageDescription)
                        .appFont(.subheadline, weight: .medium, color: .grey700)

                    Link(content.teamPageURLString, destination: URL(string: content.teamPageURLString)!)
                        .appFont(.subheadline, weight: .semibold, color: .blue)
                }
                .padding(DefaultSpacing.spacing16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.grey100)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
                    Text("감사합니다.")
                        .appFont(.bodyEmphasis, color: .grey900)

                    Text(content.signatureTitle)
                        .appFont(.subheadline, weight: .medium, color: .grey700)

                    Text(content.signatureName)
                        .appFont(.title3Emphasis, color: .grey900)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, DefaultSpacing.spacing16)
            .padding(.vertical, DefaultSpacing.spacing24)
        }
        .background(Color.white)
        .navigation(naviTitle: .productTeam, displayMode: .inline)
    }
}

#Preview {
    NavigationStack {
        ProductTeamIntroductionView()
    }
}
