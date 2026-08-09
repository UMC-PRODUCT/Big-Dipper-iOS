//
//  Progress.swift
//  UMCApp
//
//  Created by 이예지 on 5/30/26.
//

import SwiftUI
import CoreDesignSystem

public struct Progress: View {
    
    // MARK: - Property
    public let progressColor: Color
    public let message: String?
    public let messageColor: Color
    public var size: ProgressSize
    
    // MARK: - Initializer
    public init(progressColor: Color = .indigo500,
         message: String? = nil,
         messageColor: Color = .grey900,
         size: ProgressSize = .large) {
        self.progressColor = progressColor
        self.message = message
        self.messageColor = messageColor
        self.size = size
    }
    
    // MARK: - Constant
    fileprivate enum Constants {
        static let vstackSpacing: CGFloat = 10
    }
    
    // MARK: - Body
    public var body: some View {
        VStack(spacing: Constants.vstackSpacing, content: {
            ProgressView()
                .controlSize(size.controlSize)
                .tint(progressColor)
            if let message = message {
                Text(message)
                    .foregroundStyle(messageColor)
                    .appFont(size.messageSize)
            }
        })
    }
}

// MARK: - Preview
#if DEBUG
#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 100) {
        Progress(message: "로딩중!", size: .small)
        
        Progress(message: "공지를 불러오고 있어요!", size: .regular)
        
        Progress(message: "잠시만 기다려주세요!", size: .large)
    }
}
#endif
