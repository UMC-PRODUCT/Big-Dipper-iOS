//
//  MyPageProfileViewModel.swift
//  MyPage
//
//  Created by 김동민 on 7/5/26.
//

import Foundation
import SwiftUI
import PhotosUI
import CorePhoto
import MyPageDomain

/// 마이페이지 읽기 및 수정 화면의 비즈니스 로직을 담당하는 ViewModel입니다.
///
/// 프로필 데이터를 관리하고, 이미지 선택 및 업로드 동작을 처리합니다.
@Observable
public final class MyPageProfileViewModel: SinglePhotoPickerManageable {
    // MARK: - Property
    
    /// 프로타일 정보
    public var profileData: ProfileData
    private let useCaseProvider: MyPageUseCaseProviding
//    private let authUseCaseProvider: AuthUseCaseProviding
//    private let kakaoLoginManager = KakaoLoginManager()
//    private let googleLoginManager = GoogleLoginManager()
    
    /// PhotosPicker에서 선택된 아이템(PHPickerResult)
    public var selectedPhotoItem: PhotosPickerItem?
    
    /// 선택된 아이템에서 로드된 실제 이미지 객체
    public var selectedImage: UIImage?
    
    ///선택된 원본 이미지 바이너리 (업로드용)
    private var selectedImageData: Data?
    
    /// 프로필 이미지 수정 API 진행 상태
    public var isUpdatingProfileImage: Bool = false
    
    /// 활동 이력 추가 API 진행 상태
    public var isAddingACtivityLog: Bool = false
    /// 활동 이력 추가 성공 후 버튼 성공 문구 노출 상태
    public var didRecentlyAddActivityLog: Bool = false
    
    /// 소셜 연동 해제 API 진행 상태
    public var disconnectingSocialType: SocialLinkType?
    
    /// 최초 조회 / 수정 화면 진입 시 링크 스냅샷
    private var initialPorfileLinkState: [SocialLinkType: String]
    /// 활동 이력 추가 성공 문구 자동 복귀 제어 태스크
    private var activityLogAddedResetTask: Task<Void, Never>?
    
    public init(
        profileData: ProfileData,
        useCaseProvider: MyPageUseCaseProviding,
        /*
        // FIXME: - Auth 모듈 수정 후 고치기
        authUseCaseProvider: AuthUseCaseProviding
         */
    )
}
