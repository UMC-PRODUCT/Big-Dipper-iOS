//
//  SectionRightImage.swift
//  CoreUIComponents
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import SwiftUI

/// Section 또는 Row의 오른쪽에 표시되는 SF Symbol 이미지 컴포넌트
///
/// 주로 chevron, arrow 등의 네비게이션 힌트 아이콘을 일관된 스타일로 표시하기 위해 사용합니다.
///
/// - Example:
/// ```swift
/// HStack {
///     Text("설정")
///     Spacer()
///     SectionRightImage(rightImage: "chevron.right")
/// }
/// ```
public struct SectionRightImage: View {
    // MARK: - Property
    
    /// 표시할 SF Symbol 이미지 이름
    private let rightImage: String
    /// 심볼 아이콘의 크기
    private let symbolSize: CGFloat = 15
    
    // MARK: - Function
    public init(rightImage: String) {
        self.rightImage = rightImage
    }
    
    // MARK: - Body
    
    public var body: some View {
        Image(systemName: rightImage)
            .font(.system(size: symbolSize))
            .foregroundStyle(.gray)
    }
}
