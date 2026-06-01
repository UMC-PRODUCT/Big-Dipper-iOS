//
//  AppBundleSection.swift
//  AppProduct
//
//  Created by euijjang97 on 1/28/26.
//

import SwiftUI

/// MyPage에서 앱 정보(버전 등)를 표시하는 Section 컴포넌트
///
/// 앱 번들 정보를 읽어 현재 앱 버전을 사용자에게 보여줍니다.
struct InfoSection: View {
    // MARK: - Property

    private enum Constants {
        static let appStoreURLString = "https://apps.apple.com/us/app/umc/id6759412446"
        static let appStoreReviewURLString = "https://apps.apple.com/app/id6759412446?action=write-review"
        static let techBlogURLString = "https://tech.university.neordinary.com/"
        static let appName = "UMC"
        static let shareDescription = "UMC 동아리 운영을 한 곳에서 관리할 수 있는 앱이에요."
    }

    /// 섹션의 타입 (헤더 타이틀로 사용됨)
    let sectionType: MyPageSectionType

    /// Bundle에서 읽어온 앱 버전 정보
    /// - Returns: CFBundleShortVersionString 값, 없으면 "Unknown"
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    /// 공유 시트에 전달할 App Store 링크
    private var appStoreURL: URL {
        URL(string: Constants.appStoreURLString)!
    }

    /// 앱 이름, 설명, 링크를 함께 포함한 공유용 텍스트
    private var shareContent: String {
        """
        \(Constants.appName)
        \(Constants.shareDescription)
        \(appStoreURL.absoluteString)
        """
    }

    // MARK: - Function

    init(sectionType: MyPageSectionType) {
        self.sectionType = sectionType
    }

    // MARK: - Body

    var body: some View {
        Section(
            content: {
                
                MyPageSectionRow(systemIcon: "info.circle", title: "버전", rightText: appVersion, iconBackgroundColor: .cyan)
               
                Button {
                    if let url = URL(string: Constants.appStoreReviewURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    MyPageSectionRow(
                        systemIcon: "star.fill",
                        title: "앱 평가 및 리뷰",
                        rightImage: "arrow.up.right",
                        iconBackgroundColor: .pink
                    )
                }
                .buttonStyle(.plain)
                ShareLink(
                    item: shareContent,
                    preview: SharePreview(Constants.appName)
                ) {
                    MyPageSectionRow(
                        systemIcon: "square.and.arrow.up",
                        title: "앱 공유하기",
                        rightImage: "arrow.up.right",
                        iconBackgroundColor: .yellow
                    )
                }
                Button {
                    if let url = URL(string: Constants.techBlogURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    MyPageSectionRow(
                        systemIcon: "newspaper.fill",
                        title: "UMC Product Tech Blog",
                        rightImage: "arrow.up.right",
                        iconBackgroundColor: .indigo
                    )
                }
                .buttonStyle(.plain)
            },
            header: {
            SectionHeaderView(title: sectionType.rawValue)
        })
    }
}

// MARK: - Preview

#Preview("MyPage Info Section") {
    Form {
        InfoSection(sectionType: .info)
    }
}
