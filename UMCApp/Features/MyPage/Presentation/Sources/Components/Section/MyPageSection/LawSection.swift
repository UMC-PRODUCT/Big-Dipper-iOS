//
//  LawSection.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDI
import CoreUIComponents
import MyPageDomain
import SwiftUI
import UMCFoundation

/// 개인정보처리 방침 / 이용약관 링크 섹션.
///
/// 약관 링크는 서버(`fetchTermsUseCase`)가 내려주므로 탭 시점에 조회해 외부 브라우저로 엽니다.
public struct LawSection: View {

    // MARK: - Property

    private let sectionType: MyPageSectionType
    @Environment(\.di) private var di
    @Environment(\.openURL) private var openURL
    @Environment(ErrorHandler.self) private var errorHandler

    // MARK: - Init

    public init(sectionType: MyPageSectionType = .laws) {
        self.sectionType = sectionType
    }

    // MARK: - Body

    public var body: some View {
        Section(content: {
            sectionContent
        }, header: {
            SectionHeaderView(title: sectionType.rawValue)
        })
    }

    // MARK: - Function

    private var sectionContent: some View {
        ForEach(LawsType.allCases, id: \.rawValue) { law in
            content(law)
        }
    }

    private func content(_ law: LawsType) -> some View {
        Button(action: {
            Task { await openTerms(law) }
        }, label: {
            MyPageSectionRow(
                systemIcon: law.icon,
                title: law.rawValue,
                rightImage: "arrow.up.right",
                iconBackgroundColor: law.color
            )
        })
        .buttonStyle(.borderless)
    }

    @MainActor
    private func openTerms(_ law: LawsType) async {
        do {
            let provider = di.resolve(MyPageUseCaseProviding.self)
            let terms = try await provider.fetchTermsUseCase.execute(termsType: law.apiType)

            guard let url = URL(string: terms.link) else {
                throw AppError.validation(
                    .invalidFormat(field: "termsLink", expected: "https://...")
                )
            }
            openURL(url)
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: "MyPage", action: "openTerms(\(law.apiType))")
            )
        }
    }
}
