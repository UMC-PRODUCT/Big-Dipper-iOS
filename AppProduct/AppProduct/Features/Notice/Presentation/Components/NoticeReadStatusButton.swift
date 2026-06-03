//
//  NoticeReadStatusButton.swift
//  AppProduct
//
//  Created by 이예지 on 2/3/26.
//

import SwiftUI

/// 공지 열람 현황 하단 버튼
/// NoticeDetailView 하단에 표시되는 슬라이드 버튼
struct NoticeReadStatusButton: View {
    
    // MARK: - Properties
    
    let confirmedCount: Int
    let totalCount: Int
    let readRate: Double?
    let isLoading: Bool
    let action: () -> Void

    init(
        confirmedCount: Int,
        totalCount: Int,
        readRate: Double? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.confirmedCount = confirmedCount
        self.totalCount = totalCount
        self.readRate = readRate
        self.isLoading = isLoading
        self.action = action
    }
    
    // MARK: - Constants
    
    fileprivate enum Constants {
        static let iconSize: CGFloat = 16
    }
    
    // MARK: - Computed Properties
    
    private var progress: Double {
        if let readRate {
            return min(max(readRate, 0), 1)
        }
        guard totalCount > 0 else { return 0 }
        return Double(confirmedCount) / Double(totalCount)
    }
    
    private var progressText: String {
        if isLoading {
            return "불러오는 중..."
        }
        let percentage = Int(progress * 100)
        return "\(confirmedCount)/\(totalCount)명 (\(percentage)%)"
    }

    /// 진행 게이지에 입체감을 주는 그라디언트
    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [
                .blue.opacity(0.85),
                .indigo,
                .blue.opacity(0.95)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Body
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: DefaultSpacing.spacing12) {
                // 상단: 제목 + 진행률 텍스트
                HStack {
                    HStack(spacing: DefaultSpacing.spacing8) {
                        Image(systemName: "checkmark.circle.fill")
                            .appFont(.body, color: .green)
                            .symbolDrawOn(isActive: true)

                        Text("수신 확인 현황")
                            .appFont(.calloutEmphasis, color: .black)
                    }
                    
                    Spacer()
                    
                    Text(progressText)
                        .appFont(.subheadline)
                        .foregroundStyle(.black)
                }
                .foregroundStyle(.grey000)
                
                // 중간: Gauge
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(.grey400)
                } else {
                    Gauge(value: progress, in: 0...1) {}
                        .gaugeStyle(.linearCapacity)
                        .tint(progressGradient)
                }
                
                // 하단: 안내 텍스트
                Text("터치하여 미확인 인원 관리하기")
                    .appFont(.footnote, color: .grey600)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, DefaultSpacing.spacing16)
            .padding(.vertical, DefaultSpacing.spacing12)
            .background {
                RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
            }
        }
        .disabled(isLoading)
    }
}


// MARK: - Preview
#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        NoticeReadStatusButton(confirmedCount: 1100, totalCount: 1250) {
            print("Tapped")
        }
        
        NoticeReadStatusButton(confirmedCount: 3, totalCount: 8) {
            print("Tapped")
        }
        
        NoticeReadStatusButton(confirmedCount: 0, totalCount: 10) {
            print("Tapped")
        }

        NoticeReadStatusButton(
            confirmedCount: 0,
            totalCount: 0,
            isLoading: true
        ) {
            print("Loading")
        }
    }
    .padding()
}
