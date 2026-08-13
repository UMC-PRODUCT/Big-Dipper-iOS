//
//  ThreadEjectedView.swift
//  CommunityPresentation
//

import SwiftUI

/// 강퇴·스레드 삭제로 참여가 끝난 화면 (시안 #31).
///
/// 알림으로 알리다가 화면으로 승격한 이유는 알림이 덮이거나 스와이프로 넘어가면 이미 볼 수 없는
/// 방에 그대로 남기 때문이다. 이탈 경로는 이 버튼 하나뿐이라 상위가 뒤로가기를 지운다.
struct ThreadEjectedView: View {

    // MARK: - Property

    let message: String
    let onExit: () -> Void

    // MARK: - Body

    var body: some View {
        ContentUnavailableView {
            Label("참여 종료됨", systemImage: "person.slash")
        } description: {
            Text(message)
        } actions: {
            Button("커뮤니티로 돌아가기", action: onExit)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    ThreadEjectedView(message: "이 스레드에서 내보내졌어요.") {}
}
#endif
