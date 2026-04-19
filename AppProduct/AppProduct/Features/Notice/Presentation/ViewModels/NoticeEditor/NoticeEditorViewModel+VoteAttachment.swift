//
//  NoticeEditorViewModel+VoteAttachment.swift
//  AppProduct
//
//  Created by euijjang97 on 4/18/26.
//

import Foundation
import UIKit
import Photos
import PhotosUI
import SwiftUI

extension NoticeEditorViewModel {

    // MARK: - Vote Action

    func showVotingFormSheet() {
        if isVoteConfirmed {
            alertPrompt = AlertPrompt(
                id: .init(),
                title: "투표가 이미 생성되었습니다",
                message: "투표 카드를 눌러 수정하거나 삭제할 수 있습니다.",
                positiveBtnTitle: "확인"
            )
        } else {
            voteFormData = VoteFormData()
            originalVoteFormData = nil
            showVoting = true
        }
    }

    func cancelVotingEdit() {
        if isVoteConfirmed, let original = originalVoteFormData {
            voteFormData = original
        } else if !isVoteConfirmed {
            voteFormData = VoteFormData()
        }

        originalVoteFormData = nil
        showVoting = false
    }

    func confirmVote() {
        isVoteConfirmed = true
        originalVoteFormData = nil
        showVoting = false
    }

    func editVote() {
        originalVoteFormData = VoteFormData(
            title: voteFormData.title,
            options: voteFormData.options.map { VoteOptionItem(text: $0.text) },
            isAnonymous: voteFormData.isAnonymous,
            allowMultipleSelection: voteFormData.allowMultipleSelection,
            startDate: voteFormData.startDate,
            endDate: voteFormData.endDate
        )
        showVoting = true
    }

    func deleteVote() {
        voteFormData = VoteFormData()
        isVoteConfirmed = false
        originalVoteFormData = nil
    }

    func addVoteOption() {
        guard voteFormData.canAddOption else { return }
        voteFormData.options.append(VoteOptionItem())
    }

    func removeVoteOption(_ option: VoteOptionItem) {
        guard voteFormData.canRemoveOption else { return }
        voteFormData.options.removeAll { $0.id == option.id }
    }

    // MARK: - Image Action

    @MainActor
    func loadSelectedPhotoItemsForNoticeUpload() async {
        guard !selectedPhotoItems.isEmpty else { return }

        for (index, item) in selectedPhotoItems.enumerated() {
            do {
                guard let rawData = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: rawData),
                      let jpegData = image.jpegData(compressionQuality: 0.8) else {
                    continue
                }

                let sourceName = originalFileName(from: item)
                let uploadFileName = normalizedJPEGFileName(sourceName, fallbackIndex: index)

                noticeImages.append(
                    NoticeImageItem(
                        imageData: jpegData,
                        imageURL: nil,
                        uploadFileName: uploadFileName,
                        isLoading: false,
                        fileId: nil
                    )
                )
            } catch {
                continue
            }
        }

        selectedPhotoItems.removeAll()
    }

    @MainActor
    func didLoadImages(images: [UIImage]) async {
        for image in images {
            guard let imageData = image.jpegData(compressionQuality: 0.8) else { continue }
            noticeImages.append(
                NoticeImageItem(
                    imageData: imageData,
                    isLoading: false,
                    fileId: nil
                )
            )
        }

        selectedPhotoItems.removeAll()
    }

    func removeImage(_ item: NoticeImageItem) {
        noticeImages.removeAll { $0.id == item.id }
    }

    // MARK: - Link Action

    func removeLink(_ link: NoticeLinkItem) {
        noticeLinks.removeAll { $0.id == link.id }
    }

    // MARK: - Private

    private func originalFileName(from item: PhotosPickerItem) -> String? {
        guard let identifier = item.itemIdentifier else { return nil }
        let fetchedAssets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = fetchedAssets.firstObject else { return nil }
        return PHAssetResource.assetResources(for: asset).first?.originalFilename
    }

    private func normalizedJPEGFileName(_ sourceName: String?, fallbackIndex: Int) -> String {
        let fallback = "notice_image_\(Int(Date().timeIntervalSince1970))_\(fallbackIndex).jpg"
        guard let sourceName,
              !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return fallback
        }

        let nsSource = sourceName as NSString
        let baseName = nsSource.deletingPathExtension
        let sanitizedBaseName = baseName.isEmpty ? "notice_image" : baseName
        return "\(sanitizedBaseName).jpg"
    }
}
