//
//  AttachmentMenuButton.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import SwiftUI
import PhotosUI

struct AttachmentMenuButton: View {

    // MARK: - Property

    let isEditMode: Bool
    @Binding var isPhotoPickerPresented: Bool
    @Binding var selectedPhotoItems: [PhotosPickerItem]
    let onShowVotingSheet: () -> Void

    // MARK: - Constants

    private enum Constants {
        static let iconSize: CGFloat = 20
        static let frame: CGSize = .init(width: 30, height: 30)
        static let maxPhotoSelection: Int = 10
    }

    // MARK: - Body

    var body: some View {
        Menu {
            Button {
                isPhotoPickerPresented = true
            } label: {
                Label("사진", systemImage: "photo.fill")
            }

            if !isEditMode {
                Button {
                    onShowVotingSheet()
                } label: {
                    Label("투표", systemImage: "checklist")
                }
            }
        } label: {
            Image(systemName: "paperclip")
                .font(.system(size: Constants.iconSize))
                .foregroundStyle(.black)
                .frame(width: Constants.frame.width, height: Constants.frame.height)
                .padding(DefaultConstant.defaultBtnPadding)
        }
        .photosPicker(
            isPresented: $isPhotoPickerPresented,
            selection: $selectedPhotoItems,
            maxSelectionCount: Constants.maxPhotoSelection,
            matching: .images
        )
    }
}
