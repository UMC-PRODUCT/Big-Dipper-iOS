//
//  CardQRViewModel.swift
//  BusinessCardPresentation
//
//  Created by One on 8/18/26.
//

import CoreGraphics
import Foundation
import UIKit
import BusinessCardDomain
import UMCFoundation

// MARK: - Constants

private enum Constants {
    static let feature = "BusinessCard"

    static let savedTitle = "저장했어요"
    static let savedMessage = "명함 QR 이미지를 사진 앱에 저장했어요."
    static let savedConfirm = "확인"

    static let deniedTitle = "사진 접근 권한이 필요해요"
    static let deniedMessage = "설정에서 사진 추가를 허용하면 QR 이미지를 저장할 수 있어요."
    static let deniedConfirm = "설정 열기"
    static let deniedCancel = "닫기"
}

/// 내 명함 QR 화면 (MP-F02 뒷면·MP-F04). 시안 `12639:33027`.
///
/// - Important: `@MainActor` — 명함 저장소가 SwiftData `mainContext` 를 탄다.
@MainActor
@Observable
public final class CardQRViewModel {

    // MARK: - Property

    public private(set) var card: Loadable<MyCard> = .idle

    /// 생성된 QR. 카드 로드에 성공해도 생성이 실패하면 `nil` 로 남는다.
    public private(set) var qrImage: CGImage?

    public var alertPrompt: AlertPrompt?

    private let fetchMyCard: FetchMyCardUseCaseProtocol
    private let generateCardQR: GenerateCardQRUseCaseProtocol
    private let imageSaver: CardImageSaving
    private let errorHandler: ErrorHandler

    // MARK: - Init

    public init(
        fetchMyCard: FetchMyCardUseCaseProtocol,
        generateCardQR: GenerateCardQRUseCaseProtocol,
        imageSaver: CardImageSaving,
        errorHandler: ErrorHandler
    ) {
        self.fetchMyCard = fetchMyCard
        self.generateCardQR = generateCardQR
        self.imageSaver = imageSaver
        self.errorHandler = errorHandler
    }

    // MARK: - Function

    public func load() async {
        card = .loading
        qrImage = nil
        do {
            let myCard = try await fetchMyCard.execute(forceRefresh: false)
            card = .loaded(myCard)
            // QR 만 못 만들었다고 명함까지 감출 이유가 없다. 카드는 그대로 두고
            // QR 자리만 비운다 — 화면이 그 상태를 따로 그린다.
            qrImage = try? generateCardQR.execute(for: myCard)
        } catch let error as AppError {
            card = .failed(error)
        } catch {
            card = .failed(.unknown(message: error.localizedDescription))
        }
    }

    /// 공유 시트에도 저장이 있지만 시안이 버튼을 따로 뒀다 — 한 번 탭으로 끝나는 경로다.
    public func saveQRImage() async {
        guard let qrImage else { return }

        do {
            try await imageSaver.save(qrImage)
            alertPrompt = AlertPrompt(
                title: Constants.savedTitle,
                message: Constants.savedMessage,
                positiveBtnTitle: Constants.savedConfirm
            )
        } catch CardImageSaveError.permissionDenied {
            // 눌렀는데 아무 일도 안 일어나면 사용자는 버튼이 고장 났다고 여긴다.
            // 우리가 못 고치는 상태라 설정으로 보낸다.
            alertPrompt = AlertPrompt(
                title: Constants.deniedTitle,
                message: Constants.deniedMessage,
                positiveBtnTitle: Constants.deniedConfirm,
                positiveBtnAction: { Self.openSettings() },
                negativeBtnTitle: Constants.deniedCancel
            )
        } catch {
            errorHandler.handle(
                error,
                context: ErrorContext(feature: Constants.feature, action: "saveQRImage")
            )
        }
    }

    // MARK: - Private Function

    private static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
