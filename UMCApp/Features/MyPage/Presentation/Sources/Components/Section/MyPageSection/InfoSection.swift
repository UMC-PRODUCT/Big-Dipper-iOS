//
//  InfoSection.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreUIComponents
import SwiftUI

/// 앱 버전·리뷰·공유·기술 블로그 등 앱 정보 섹션.
public struct InfoSection: View {

    // MARK: - Property

    private let sectionType: MyPageSectionType
    @Environment(\.openURL) private var openURL

    private enum Constants {
        static let appName = "UMC"
        static let shareDescription = "UMC 동아리 운영을 한 곳에서 관리할 수 있는 앱이에요."
        static let appStoreURL = "https://apps.apple.com/us/app/umc/id6759412446"
        static let reviewURL = "https://apps.apple.com/app/id6759412446?action=write-review"
        static let techBlogURL = "https://tech.university.neordinary.com/"
        static let unknownVersion = "Unknown"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? Constants.unknownVersion
    }

    private var shareContent: String {
        """
        \(Constants.appName)
        \(Constants.shareDescription)
        \(Constants.appStoreURL)
        """
    }

    // MARK: - Init

    public init(sectionType: MyPageSectionType = .info) {
        self.sectionType = sectionType
    }

    // MARK: - Body

    public var body: some View {
        Section(content: {
            MyPageSectionRow(
                systemIcon: "info.circle",
                title: "버전",
                rightText: appVersion,
                iconBackgroundColor: .cyan
            )

            linkRow(systemIcon: "star.fill", title: "앱 평가 및 리뷰", color: .pink) {
                open(Constants.reviewURL)
            }

            ShareLink(item: shareContent, preview: SharePreview(Constants.appName)) {
                MyPageSectionRow(
                    systemIcon: "square.and.arrow.up",
                    title: "앱 공유하기",
                    rightImage: "arrow.up.right",
                    iconBackgroundColor: .yellow
                )
            }

            linkRow(
                systemIcon: "newspaper.fill",
                title: "UMC PRODUCT 소개",
                color: .indigo
            ) {
                open(Constants.techBlogURL)
            }
        }, header: {
            SectionHeaderView(title: sectionType.rawValue, weight: .semibold)
        })
    }

    // MARK: - Function

    private func linkRow(
        systemIcon: String,
        title: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action, label: {
            MyPageSectionRow(
                systemIcon: systemIcon,
                title: title,
                rightImage: "arrow.up.right",
                iconBackgroundColor: color
            )
        })
        .buttonStyle(.borderless)
    }

    private func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        openURL(url)
    }
}
