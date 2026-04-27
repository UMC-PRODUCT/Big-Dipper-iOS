import Foundation
import SwiftUI

/// 전역 레이아웃 상수.
///
/// 앱 전체에서 일관된 간격, 패딩, 모서리 반경 등을 적용하기 위한 상수 모음입니다.
public enum DefaultConstant {
    public static let iconSize: CGFloat = 36
    public static let cornerRadius: CGFloat = 24
    public static let iconPadding: CGFloat = 8

    public static let defaultSafeHorizon: CGFloat = 16
    public static let defaultSafeTop: CGFloat = 20
    public static let defaultSafeBottom: CGFloat = 56

    public static let defaultCapsuleSpacing: CGFloat = 28
    public static let defaultSafeBtnPadding: CGFloat = 10

    public static let defaultCornerRadius: CGFloat = 30
    public static let concentricRadius: Edge.Corner.Style = 40

    public static let defaultContentBottomMargins: CGFloat = 40
    public static let defaultContentTopMargins: CGFloat = 20
    public static let defaultContentTrailingMargins: CGFloat = 4

    public static let defaultBtnPadding: CGFloat = 10
    public static let defaultToolBarTitlePadding: EdgeInsets = .init(top: 8, leading: 16, bottom: 8, trailing: 16)

    public static let defaultTextFieldPadding: CGFloat = 14
    public static let defaultTopCapsuleSpacing: CGFloat = 10

    public static let defaultListPadding: EdgeInsets = .init(top: 16, leading: 16, bottom: 16, trailing: 16)
    public static let defaultCardPadding: EdgeInsets = .init(top: 24, leading: 16, bottom: 24, trailing: 16)

    public static let sectionLeadingHeader: CGFloat = 24

    public static let animationTime: TimeInterval = 0.3
    public static let transitionScale: CGFloat = 0.95

    public static let lineSpacing: CGFloat = 2.5
    public static let badgePadding: EdgeInsets = .init(top: 8, leading: 16, bottom: 8, trailing: 16)
}

// MARK: - System Image Constants

public extension DefaultConstant {
    static let chevronForwardImage: String = "chevron.forward"
    static let chevronUpImage: String = "chevron.up"
    static let chevronDownImage: String = "chevron.down"
}
