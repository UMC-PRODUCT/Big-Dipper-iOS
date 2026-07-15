//
//  SectionHeaderView.swift
//  CoreUIComponents
//
//  Created by 김동민 on 7/4/26.
//

import SwiftUI
import CoreDesignSystem

/// Section의 헤더 타이틀을 표시하는 공통 뷰 컴포넌트
///
/// Form 또는 List의 섹션 헤더에서 일관된 스타일의 타이틀을 표시하기 위해 사용합니다.
///
/// - Example:
/// ```swift
/// Section(content: {
///     // content
/// }, header: {
///     SectionHeaderView(title: "설정")
/// })
/// ```
public struct SectionHeaderView: View {
    // MARK: - Property

    /// 섹션 헤더에 표시할 타이틀 텍스트
    private let title: String
    
    // MARK: - Function
    public init(title: String) {
        self.title = title
    }
    
    // MARK: - Body
    
    public var body: some View {
        Text(title)
            .appFont(.body, color: .black)
    }
}
