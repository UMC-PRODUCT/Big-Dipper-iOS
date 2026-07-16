//
//  VoteAttachmentCard.swift
//  NoticePresentation
//
//  Created by 이예지 on 7/3/26.
//

import SwiftUI
import CoreDesignSystem
import NoticeDomain

// MARK: - VoteCardMode
/// 투표 카드 표시 모드
enum VoteCardMode {
    case editable    // 공지 작성: 수정 가능
    case readonly    // 공지 수정: 읽기 전용 (삭제만 가능)
}

// MARK: - VoteAttachmentCard
/// 공지 에디터 하단에 표시되는 투표 첨부 카드
struct VoteAttachmentCard: View {

    // MARK: - Property

    /// 투표 폼 데이터 바인딩
    @Binding var formData: VoteFormData
    /// 카드 모드(수정 가능/읽기 전용)
    var mode: VoteCardMode = .editable
    /// 투표 삭제 액션
    var onDelete: (() -> Void)?
    /// 투표 수정 액션
    var onEdit: (() -> Void)? = nil

    // MARK: - Constants

    fileprivate enum Constants {
        static let textSpacing: CGFloat = 35
        static let bgOpacity: Double = 0.6
    }

    // MARK: - Body

    var body: some View {
        HStack(alignment: .center) {
            textSection
            Spacer()
            iconSection
        }
        .padding(DefaultConstant.defaultSafeHorizon)
        .background {
            RoundedRectangle(cornerRadius: DefaultConstant.defaultCornerRadius)
                .fill(Color.indigo100)
                .opacity(Constants.bgOpacity)
                .glassEffect(.clear, in: .rect(cornerRadius: DefaultConstant.defaultCornerRadius))
        }
    }

    // MARK: - Helper

    /// 카드 좌측 텍스트 영역
    private var textSection: some View {
        VStack(alignment: .leading, spacing: DefaultSpacing.spacing8) {
            Label("투표", systemImage: "chart.bar.fill")
                .appFont(.callout, weight: .semibold)
            Text("\(anonymousLabel), \(allowMultipleLabel), \(formData.validOptionsCount)개 항목")
                .padding(.leading, Constants.textSpacing)
                .appFont(.footnote, color: .grey500)
        }
    }

    /// 익명 여부 텍스트
    private var anonymousLabel: String {
        formData.isAnonymous ? "익명" : "공개"
    }

    /// 복수 선택 여부 텍스트
    private var allowMultipleLabel: String {
        formData.allowMultipleSelection ? "복수 선택 가능" : "1개 선택 가능"
    }

    /// 카드 우측 액션 아이콘 영역
    private var iconSection: some View {
        Group {
            switch mode {
            case .editable:
                Menu {
                    if let onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Label("수정하기", systemImage: "pencil")
                        }
                    }

                    Button(role: .destructive) {
                        onDelete?()
                    } label: {
                        Label("삭제하기", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.grey500)
                }
            case .readonly:
                Button {
                    onDelete?()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(Color.grey500)
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    @Previewable @State var formData = VoteFormData()
    
    VStack {
        VoteAttachmentCard(formData: $formData, mode: .editable)
        
        VoteAttachmentCard(
            formData: $formData,
            mode: .readonly,
            onDelete: { print("투표 삭제됨") }
        )
    }
}
