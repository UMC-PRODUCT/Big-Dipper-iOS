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
        /// 직전 1회 실행에서 소비한 토큰 수
        let lastRunTokens: Int
        /// 에디터가 열린 뒤 누적 사용량 (직전 실행 포함)
        let cumulativeUsed: Int
        /// 모델 컨텍스트 윈도우 크기
        let total: Int

        var remaining: Int { max(0, total - cumulativeUsed) }
        var progress: Double {
            guard total > 0 else { return 0 }
            return min(1, Double(cumulativeUsed) / Double(total))
        }
    }

    // MARK: - AI Content Improvement

    /// Foundation Model을 사용해 공지 본문을 개선합니다.
    ///
    /// 현재 본문 텍스트를 온디바이스 언어 모델로 개선하여 재작성합니다.
    /// 처리 중에는 `isAIProcessing`이 true가 되며, 스트리밍 진행 상황은 `aiStreamingText`에 반영됩니다.
    /// iOS 26.4 이상에서는 `aiTokenUsage`에 에디터 세션 누적 기준 토큰 사용량이 반영되며,
    /// 정상 완료 후에는 `showAICompletionSummary`가 true가 되어 사용자가 확인 버튼을 누를 때까지 오버레이가 유지됩니다.
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
        showAICompletionSummary = false

        do {
            let session = LanguageModelSession {
                """
                당신은 동아리 공지사항 작성 전문가입니다.
                주어진 글의 핵심 내용과 의도는 그대로 유지하면서, 더 명확하고 자연스럽게 개선하여 다시 작성해주세요.
                별도의 설명이나 메타 텍스트 없이 개선된 글만 출력하세요.
                """
            }

            let contextSize = resolveContextSize()
            if let contextSize {
                aiTokenUsage = AITokenUsage(
                    lastRunTokens: 0,
                    cumulativeUsed: min(aiCumulativeUsedTokens, contextSize),
                    total: contextSize
                )
            }

            let stream = session.streamResponse(to: plainText)
            var fullText = ""
            var chunkIndex = 0
            var lastRunTokens = 0
            for try await partial in stream {
                fullText = partial.content
                aiStreamingText = fullText
                chunkIndex += 1
                if let contextSize, chunkIndex.isMultiple(of: 5) {
                    lastRunTokens = await updateTokenUsage(session: session, contextSize: contextSize)
                }
            }
            if let contextSize {
                lastRunTokens = await updateTokenUsage(session: session, contextSize: contextSize)
            }

            if !fullText.isEmpty {
                let baseFont = UIFont(name: "Pretendard-Regular", size: 16)
                    ?? UIFont.preferredFont(forTextStyle: .body)
                richAttributedContent = MarkdownSerializer.deserialize(fullText, baseFont: baseFont)
                content = MarkdownSerializer.serialize(richAttributedContent)
            }

            if let contextSize {
                aiCumulativeUsedTokens = min(aiCumulativeUsedTokens + lastRunTokens, contextSize)
                aiTokenUsage = AITokenUsage(
                    lastRunTokens: lastRunTokens,
                    cumulativeUsed: aiCumulativeUsedTokens,
                    total: contextSize
                )
            }

            isAIProcessing = false
            showAICompletionSummary = true
        } catch {
            isAIProcessing = false
            aiStreamingText = ""
            showAICompletionSummary = false
            errorHandler?.handle(
                error,
                context: ErrorContext(
                    feature: "Notice",
                    action: "improveContentWithAI"
                )
            )
        }
    }

    /// 완료 요약 오버레이를 닫습니다. 확인 버튼 핸들러에서 호출됩니다.
    @MainActor
    func dismissAICompletionSummary() {
        showAICompletionSummary = false
        aiStreamingText = ""
    }

    // MARK: - Token Usage

    /// 모델의 컨텍스트 윈도우 크기를 조회합니다. (iOS 26.4+)
    private func resolveContextSize() -> Int? {
        guard #available(iOS 26.4, *) else { return nil }
        return SystemLanguageModel.default.contextSize
    }

    /// 현재 세션 트랜스크립트 기준 이번 실행 토큰 사용량을 갱신하고, 누적값을 반영한 스냅샷을 `aiTokenUsage`에 세팅합니다.
    /// - Returns: 이번 실행에서 소비된 토큰 수 (실패 시 0)
    @MainActor
    private func updateTokenUsage(session: LanguageModelSession, contextSize: Int) async -> Int {
        guard #available(iOS 26.4, *) else { return 0 }
        do {
            let used = try await SystemLanguageModel.default.tokenCount(for: session.transcript)
            let cumulative = min(aiCumulativeUsedTokens + used, contextSize)
            aiTokenUsage = AITokenUsage(
                lastRunTokens: used,
                cumulativeUsed: cumulative,
                total: contextSize
            )
            return used
        } catch {
            return 0
        }
    }
}
