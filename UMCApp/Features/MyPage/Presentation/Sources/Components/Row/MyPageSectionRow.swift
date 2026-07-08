//
//  MyPageSectionRow.swift
//  MyPage
//
//  Created by 김동민 on 7/4/26.
//

import SwiftUI
import CoreDesignSystem
import CoreUIComponents

/// MyPage에서 사용되는 재사용 가능한 Row 컴포넌트
///
/// 왼쪽 아이콘, 중앙 타이틀, 오른쪽 컨텐츠(이미지 또는 텍스트)로 구성된 표준 Row 레이아웃을 제공합니다.
/// SF Symbol 사용 시 자동으로 원형 배경이 적용됩니다.
///
/// - Example:
/// ```swift
/// // 이미지 리소스 + 오른쪽 이미지
/// MyPageSectionRow(icon: .github, title: "GitHub", rightImage: "arrow.up.right")
///
/// // SF Symbol + 오른쪽 텍스트 (기본 배경색)
/// MyPageSectionRow(systemIcon: "info.circle", title: "버전", rightText: "1.0.0")
///
/// // SF Symbol + 커스텀 배경색
/// MyPageSectionRow(systemIcon: "bell.fill", title: "알림", rightText: "On", iconBackgroundColor: .blue.opacity(0.2))
/// ```
public struct MyPageSectionRow: View {
    // MARK: - Property
    
    /// 왼쪽에 표시할 아이콘 타입(ImageResource 또는 SF Symbol)
    private let icon: RowIconType
    /// 중앙에 표시할 타이틀 텍스트
    private let title: String
    /// 오른쪽에 표시할 컨텐츠 타입(이미지, 텍스트, 없음)
    private let rightContent: RowRightContentType
    /// SF Symbol의 circle 배경색(system icon인 경우에만 사용)
    private let iconBackgroundColor: Color?
    /// 타이틀 텍스트 색상(기본값:  .black)
    private let titleColor: Color
    
    // MARK: - Function
    
    /// ImageResource 아이콘과 오른쪽 이미지를 사용하는 Row 생성자
    /// - Parameters:
    ///   - icon: 왼쪽에 표시할 이미지 리소스
    ///   - title: 중앙에 표시할 타이틀
    ///   - rightImage: 오른쪽에 표시할 SF Symbol 이름
    ///   - titleColor: 타이틀 텍스트 색상 (기본값: .black)
    public init(icon: ImageResource, title: String, rightImage: String, titleColor: Color = .black) {
        self.icon = .resource(icon)
        self.title = title
        self.rightContent = .image(rightImage)
        self.iconBackgroundColor = nil
        self.titleColor = titleColor
    }
    
    /// SF Symbol 아이콘과 오른쪽 이미지를 사용하는 Row 생성자
    /// - Parameters:
    ///   - systemIcon: 왼쪽에 표시할 SF Symbol 이름
    ///   - title: 중앙에 표시할 타이틀
    ///   - rightImage: 오른쪽에 표시할 SF Symbol 이름
    ///   - iconBackgroundColor: SF Symbol의 circle 배경색 (기본값: .clear)
    ///   - titleColor: 타이틀 텍스트 색상 (기본값: .black)
    public init (systemIcon: String, title: String, rightImage: String, iconBackgroundColor: Color = .clear, titleColor: Color = .black) {
        self.icon = .system(systemIcon)
        self.title = title
        self.rightContent = .image(rightImage)
        self.iconBackgroundColor = iconBackgroundColor
        self.titleColor = titleColor
    }
    
    /// ImageResource 아이콘과 오른쪽 텍스트를 사용하는 Row 생성자
    /// - Parameters:
    ///   - icon: 왼쪽에 표시할 이미지 리소스
    ///   - title: 중앙에 표시할 타이틀
    ///   - rightText: 오른쪽에 표시할 텍스트
    ///   - titleColor: 타이틀 텍스트 색상 (기본값: .black)
    public init (icon: ImageResource, title: String, rightText: String, titleColor: Color = .black) {
        self.icon = .resource(icon)
        self.title = title
        self.rightContent = .text(rightText)
        self.iconBackgroundColor = nil
        self.titleColor = titleColor
    }
    
    /// SF Symbol 아이콘과 오른쪽 텍스트를 사용하는 Row 생성자
    /// - Parameters:
    ///   - systemIcon: 왼쪽에 표시할 SF Symbol 이름
    ///   - title: 중앙에 표시할 타이틀
    ///   - rightText: 오른쪽에 표시할 텍스트
    ///   - iconBackgroundColor: SF Symbol의 circle 배경색 (기본값: .clear)
    ///   - titleColor: 타이틀 텍스트 색상 (기본값: .black)
    public init (systemIcon: String, title: String, rightText: String, iconBackgroundColor: Color = .clear, titleColor: Color = .black) {
        self.icon = .system(systemIcon)
        self.title = title
        self.rightContent = .text(rightText)
        self.iconBackgroundColor = iconBackgroundColor
        self.titleColor = titleColor
    }
    
    /// MyPageSectionRow 내부에서 사용하는 상수
    private enum Constants {
        static let linkIcon: CGFloat = 30
        static let cornerRadius: CGFloat = 10
        static let concentric: Edge.Corner.Style = 10
        static let rectangleSize: CGFloat = 30
        static let imageSize: CGFloat = 16
    }
    
    // MARK: - Body
    
    public var body: some View {
        HStack(spacing: DefaultSpacing.spacing8) {
            iconView
            Text(title)
                .appFont(.subheadline, weight: .medium, color: titleColor)

            Spacer()
            rightContentView
        }
    }
    
    /// 아이콘 타입에 따라 적절한 스타일이 적용된 아이콘 뷰를 반환
    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .resource(let imageResource):
            Image(imageResource)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Constants.linkIcon, height: Constants.linkIcon)
                .clipShape(.rect(corners: .concentric(minimum: Constants.concentric), isUniform: true))
        case .system(let systemName):
            ZStack {
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .fill(iconBackgroundColor ?? .grey200)
                    .frame(width: Constants.rectangleSize, height: Constants.rectangleSize)
                    .glassEffect(.clear, in: RoundedRectangle(cornerRadius: Constants.cornerRadius))
                
                Image(systemName: systemName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Constants.imageSize, height: Constants.imageSize)
                    .foregroundStyle(.white)
            }
        }
    }
    
    /// 오른쪽 컨텐츠 타입에 따라 적절한 뷰를 반환하는 computed property
    @ViewBuilder
    private var rightContentView: some View {
        switch rightContent {
        case .image(let imageName):
            SectionRightImage(rightImage: imageName)
        case .text(let text):
            Text(text)
                .appFont(.subheadline, weight: .regular, color: .grey500)
        case .none:
            EmptyView()
        }
    }
}

/// MyPageSectionRow에서 사용하는 아이콘 타입
internal enum RowIconType {
    /// 앱 내부 이미지 리소스
    case resource(ImageResource)
    /// SF Symbol 시스템 이미지
    case system(String)
}


/// MyPageSectionRow 오른쪽에 표시할 컨텐츠 타입
internal enum RowRightContentType {
    /// 이미지(SF Symbol 또는 Asset)
    case image(String)
    /// 텍스트
    case text(String)
    /// 없음
    case none
}
