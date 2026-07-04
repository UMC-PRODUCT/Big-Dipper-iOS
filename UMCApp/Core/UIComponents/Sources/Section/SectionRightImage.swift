//
//  SectionRightImage.swift
//  CoreUIComponents
//
//  Created by 김동민 on 7/4/26.
//

import Foundation
import SwiftUI

public struct SectionRightImage: View {
    // MARK: - Property
    
    /// 표시할 SF Symbol 이미지 이동
    private let rightImage: String
    /// 심볼 아이콘의 크기
    private let simbolSize: CGFloat = 15
    
    // MARK: - Function
    public init(rightImage: String) {
        self.rightImage = rightImage
    }
    
    // MARK: - Body
    
    public var body: some View {
        Image(systemName: rightImage)
            .font(.system(size: simbolSize))
            .foregroundStyle(.gray)
    }
}
