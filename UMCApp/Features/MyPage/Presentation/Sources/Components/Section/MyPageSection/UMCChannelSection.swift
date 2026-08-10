//
//  UMCChannelSection.swift
//  MyPagePresentation
//
//  Created by euijjang97 on 8/10/26.
//

import CoreDesignSystem
import CoreUIComponents
import SwiftUI

/// UMC 공식 채널(Instagram·웹사이트) 바로가기 섹션.
///
/// 앱 딥링크가 있는 채널은 딥링크를 먼저 시도하고, 처리할 앱이 없으면 웹으로 폴백한다.
public struct UMCChannelSection: View {

    // MARK: - Property

    private let sectionType: MyPageSectionType
    @Environment(\.openURL) private var openURL

    // MARK: - Init

    public init(sectionType: MyPageSectionType = .umcChannels) {
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
        HStack(spacing: DefaultSpacing.spacing12) {
            ForEach(UMCChannelType.allCases, id: \.rawValue) { channel in
                content(channel)
            }
        }
    }

    private func content(_ channel: UMCChannelType) -> some View {
        Button(action: {
            open(channel)
        }, label: {
            channel.icon
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.iconSize, height: Constants.iconSize)
                .clipShape(.circle)
                .glassEffect(.clear.interactive(), in: .circle)
        })
        .buttonStyle(.borderless)
        .accessibilityLabel(channel.accessibilityLabel)
    }

    /// 딥링크 → 웹 순으로 채널을 연다.
    ///
    /// `openURL` 의 completion 은 URL 을 처리할 앱이 없으면 `false` 를 돌려주므로,
    /// `UIApplication.canOpenURL` + `LSApplicationQueriesSchemes` 등록 없이 폴백할 수 있다.
    private func open(_ channel: UMCChannelType) {
        guard let appURL = channel.appURL else {
            channel.url.map { openURL($0) }
            return
        }

        openURL(appURL) { accepted in
            guard !accepted, let webURL = channel.url else { return }
            openURL(webURL)
        }
    }
}

// MARK: - Constants

private enum Constants {
    static let iconSize: CGFloat = 48
}
