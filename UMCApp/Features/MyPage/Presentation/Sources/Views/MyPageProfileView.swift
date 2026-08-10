//
//  MyPageProfileView.swift
//  MyPage
//
//  Created by 김동민 on 7/8/26.
//

import SwiftUI
import PhotosUI
import UMCFoundation
import AuthDomain
import CoreDI
import MyPageDomain

/// 마이페이지 정보 Write & Read 화면입니다.
///
/// 사용자의 프로필 이미지, 닉네임, 학교, 활동 로그, 소셜 링크 등을 확인하고 수정할 수 있습니다.
public struct MyPageProfileView: View {
    
    // MARK: - Property
    @State private var viewModel: MyPageProfileViewModel
    @Environment(\.di) private var di
    @Environment(ErrorHandler.self) private var errorHandler
    @Environment(\.dismiss) private var dismiss
    @State private var showAddActivityLogAlert: Bool = false
    @State private var challengerCode: String = ""
    @State private var alertPrompt: AlertPrompt?
    
    public init(container: DIContainer, profileData: ProfileData) {
        self._viewModel = .init(
            initialValue: .init(
                profileData: profileData,
                useCaseProvider: container.resolve(MyPageUseCaseProviding.self),
                fetchMyOAuthUseCase: container.resolve(FetchMyOAuthUseCaseProtocol.self),
                deleteMemberOAuthUseCase: container.resolve(DeleteMemberOAuthUseCaseProtocol.self)
            )
        )
    }
    
    public var body: some View {
        Text("")
    }
    
    /// 섹션 구현부
    /// - Parameter profile: 프로필 데이터 바인딩
    @ViewBuilder
    private func sectionConnectionImpl(_ profile: Binding<ProfileData>) -> some View {
        // 프로필 이미지 수정
        ProfileImagePicker(selectedPhotoItem: $viewModel.selectedPhotoItem, selectedImage: viewModel.selectedImage, profileImage: viewModel.profileData.challengerInfo.profileImage)
        
    }
}
