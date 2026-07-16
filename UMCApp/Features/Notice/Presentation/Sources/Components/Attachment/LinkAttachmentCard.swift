//
//  LinkAttachmentCard.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import CoreDesignSystem
import NoticeDomain

struct LinkAttachmentCard: View, Equatable {
    
    // MARK: - Property
    @Binding var link: String
    var shouldAutoFocus: Bool = false
    var onDismiss: () -> Void
    @FocusState private var isLinkFieldFocused: Bool
    
    // MARK: - Constant
    fileprivate enum Constants {
        static let mainPadding: CGFloat = 12
        static let bgOpacity: Double = 0.6
        static let xmarkSize: CGFloat = 16
        static let xmarkPadding: CGFloat = 2
        static let topSectionHPadding: CGFloat = 12
        static let textfieldPadding: EdgeInsets = .init(top: 8, leading: 12, bottom: 8, trailing: 12)
    }
    
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.link == rhs.link && lhs.shouldAutoFocus == rhs.shouldAutoFocus
    }
    
    // MARK: - Body
    var body: some View {
        VStack {
            topSection
            textfieldSection
        }
        .padding(Constants.mainPadding)
        .background {
            RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                .fill(Color.indigo100)
                .opacity(Constants.bgOpacity)
                .glassEffect(.clear, in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
        }
    }
    
    /// 링크 카드 타이틀, 카드 삭제 버튼
    private var topSection: some View {
        HStack {
            Label("링크 첨부", systemImage: "link")
                .appFont(.callout, weight: .semibold)
            Spacer()
            Button(action: {
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: Constants.xmarkSize))
                    .padding(Constants.xmarkPadding)
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, Constants.topSectionHPadding)
    }
    
    /// 링크 TextField
    private var textfieldSection: some View {
        TextField("",
                  text: $link,
                  prompt: Text(verbatim: "https://example.com"))
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
            .autocorrectionDisabled()
            .appFont(.subheadline)
            .focused($isLinkFieldFocused)
            .padding(Constants.textfieldPadding)
            .background {
                RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                    .fill(Color.grey000)
            }
            .task {
                guard shouldAutoFocus else { return }
                await MainActor.run {
                    isLinkFieldFocused = true
                }
            }
            .onChange(of: shouldAutoFocus) { _, newValue in
                guard newValue else { return }
                Task { @MainActor in
                    isLinkFieldFocused = true
                }
            }
    }
}

// MARK: - Preview
#Preview {
    @Previewable @State var noticeLinkItems: [NoticeLinkItem] = []
    
    VStack(spacing: 12) {
        ForEach($noticeLinkItems) { $item in
            LinkAttachmentCard(link: $item.link) {
                noticeLinkItems.removeAll { $0.id == item.id }
            }
        }
        
        Button("링크 카드 추가") {
            noticeLinkItems.append(NoticeLinkItem(link: "www.umc.com"))
        }
    }
    .safeAreaPadding(.horizontal, DefaultConstant.defaultSafeHorizon)
}
