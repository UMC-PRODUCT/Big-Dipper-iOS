//
//  NoticeEditorViewModel+AI.swift
//  AppProduct
//
//  Created by euijjang97 on 4/8/26.
//

import Foundation
import FoundationModels
import UIKit

extension NoticeEditorViewModel {

    // MARK: - Types

    /// AI 토큰 사용량 스냅샷
    struct AITokenUsage: Equatable {
        let used: Int
        let total: Int

        var remaining: Int { max(0, total - used) }
        var progress: Double {
            guard total > 0 else { return 0 }
            return min(1, Double(used) / Double(total))
        }
    }

    // MARK: - AI Content Improvement

    /// Foundation Model을 사용해 공지 본문을 개선합니다.
    ///
    /// 현재 본문 텍스트를 온디바이스 언어 모델로 개선하여 재작성합니다.
    /// 처리 중에는 `isAIProcessing`이 true가 되며, 스트리밍 진행 상황은 `aiStreamingText`에 반영됩니다.
    /// iOS 26.4 이상에서는 `aiTokenUsage`에 토큰 사용량이 누적 반영됩니다.
    @MainActor
    func improveContentWithAI() async {
        let plainText = richAttributedContent.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !plainText.isEmpty else { return }

        guard case .available = SystemLanguageModel.default.availability else {
            alertPrompt = AlertPrompt(
                title: "AI 기능 사용 불가",
                message: "이 기기에서는 Apple Intelligence를 사용할 수 없습니다. 설정에서 Apple Intelligence를 활성화해주세요.",
                positiveBtnTitle: "확인"
            )
            return
        }

        isAIProcessing = true
        aiStreamingText = ""
        aiTokenUsage = nil

        defer {
            isAIProcessing = false
            aiStreamingText = ""
            aiTokenUsage = nil
        }

        do {
            let session = LanguageModelSession {
                """
                당신은 동아리 공지사항 작성 전문가입니다.
                주어진 글의 핵심 내용과 의도는 그대로 유지하면서, 더 명확하고 자연스럽게 개선하여 다시 작성해주세요.
                별도의 설명이나 메타 텍스트 없이 개선된 글만 출력하세요.
                """
            }

            let contextSize = await resolveContextSize()
            if let contextSize {
                aiTokenUsage = AITokenUsage(used: 0, total: contextSize)
            }

            let stream = session.streamResponse(to: plainText)
            var fullText = ""
            for try await partial in stream {
                fullText = partial.content
                aiStreamingText = fullText
                if let contextSize {
                    await updateTokenUsage(session: session, contextSize: contextSize)
                }
            }

            if !fullText.isEmpty {
                let baseFont = UIFont(name: "Pretendard-Regular", size: 16)
                    ?? UIFont.preferredFont(forTextStyle: .body)
                richAttributedContent = MarkdownSerializer.deserialize(fullText, baseFont: baseFont)
                content = MarkdownSerializer.serialize(richAttributedContent)
            }
        } catch {
            errorHandler?.handle(
                error,
                context: ErrorContext(
                    feature: "Notice",
                    action: "improveContentWithAI"
                )
            )
        }
    }

    // MARK: - Token Usage

    /// 모델의 컨텍스트 윈도우 크기를 조회합니다.
    /// `contextSize`는 iOS 26.4 미만에도 back-deploy 되어 별도 가드 없이 호출 가능합니다.
    private func resolveContextSize() async -> Int? {
        await SystemLanguageModel.default.contextSize
    }

    /// 현재 세션 트랜스크립트 기준 토큰 사용량을 갱신합니다. (iOS 26.4+)
    @MainActor
    private func updateTokenUsage(session: LanguageModelSession, contextSize: Int) async {
        guard #available(iOS 26.4, *) else { return }
        do {
            let usage = try await SystemLanguageModel.default.tokenUsage(for: session.transcript)
            aiTokenUsage = AITokenUsage(
                used: min(usage.tokenCount, contextSize),
                total: contextSize
            )
        } catch {
            // 토큰 계산 실패는 무시 — 기능 동작에는 영향 없음
        }
    }
}
