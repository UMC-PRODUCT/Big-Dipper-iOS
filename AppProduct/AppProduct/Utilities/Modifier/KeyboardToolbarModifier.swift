//
//  KeyboardToolbarModifier.swift
//  AppProduct
//
//  Created by euijjang97 on 1/12/26.
//

import SwiftUI

/// 키보드 툴바 수정자 - 이전/다음/완료 버튼 제공
struct KeyboardToolbarModifier<Field: Hashable & CaseIterable>: ViewModifier {
    
    // MARK: - Properties
    @FocusState.Binding var focusedField: Field?
    @Namespace var namespace
    
    // MARK: - Body
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, content: {
                if focusedField != nil {
                    bottomToolbar
                }
            })
    }
    
    private var bottomToolbar: some View {
        GlassEffectContainer(content: {
            HStack(content: {
                toolBarButton(action: {
                    moveToPreviousField()
                }, image: "chevron.up")
                .disabled(!canMoveToPrevious)
                
                toolBarButton(action: {
                    moveToNextField()
                }, image: "chevron.down")
                .disabled(!canMoveToNext)
                
                Spacer()
                
                toolBarButton(action: {
                    focusedField = nil
                }, image: "checkmark", size: .init(width: 20, height: 20))
                .symbolDrawOn(isActive: true)
            })
        })
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.bottom, 5)
    }
    
    private func toolBarButton(action: @escaping () -> Void, image: String, size: CGSize = .init(width: 18, height: 18)) -> some View {
        Button(action: {
            action()
        }, label: {
            Image(systemName: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: size.width, height: size.height)
                .tint(.grey900)
                .padding(DefaultConstant.defaultBtnPadding)
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEffectID(image, in: namespace)
        })
    }
    
    // MARK: - Computed Properties
    private var canMoveToPrevious: Bool {
        guard let current = focusedField else { return false }
        return previousField(from: current) != nil
    }
    
    private var canMoveToNext: Bool {
        guard let current = focusedField else { return false }
        return nextField(from: current) != nil
    }
    
    // MARK: - Methods
    private func moveToPreviousField() {
        guard let current = focusedField,
              let previous = previousField(from: current) else { return }
        focusedField = previous
    }
    
    private func moveToNextField() {
        guard let current = focusedField,
              let next = nextField(from: current) else { return }
        focusedField = next
    }
    
    private func previousField(from field: Field) -> Field? {
        let allCases = Array(Field.allCases)
        guard let currentIndex = allCases.firstIndex(of: field), currentIndex > 0 else {
            return nil
        }
        return allCases[currentIndex - 1]
    }
    
    private func nextField(from field: Field) -> Field? {
        let allCases = Array(Field.allCases)
        guard let currentIndex = allCases.firstIndex(of: field), currentIndex < allCases.count - 1 else {
            return nil
        }
        return allCases[currentIndex + 1]
    }
}

// MARK: - Keyboard Dismiss Toolbar Modifier

/// 키보드 완료 툴바 수정자 - 완료 버튼만 제공
struct KeyboardDismissToolbarModifier: ViewModifier {

    // MARK: - Properties
    @FocusState.Binding var focusedID: UUID?

    // MARK: - Body
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                if focusedID != nil {
                    dismissToolbar
                }
            }
    }

    private var dismissToolbar: some View {
        HStack {
            Spacer()
            Button {
                focusedID = nil
            } label: {
                Image(systemName: "checkmark")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .tint(.grey900)
                    .padding(DefaultConstant.defaultBtnPadding)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .symbolDrawOn(isActive: true)
            }
        }
        .padding(.horizontal, DefaultConstant.defaultSafeHorizon)
        .padding(.bottom, 5)
    }
}

// MARK: - View Extensions

extension View {
    /// 키보드 툴바를 추가합니다.
    ///
    /// 이전/다음 버튼으로 필드 간 이동하고, 완료 버튼으로 키보드를 내릴 수 있습니다.
    /// Field 타입은 CaseIterable을 준수해야 하며, allCases 순서대로 이동합니다.
    ///
    /// - Parameter focusedField: FocusState 바인딩
    ///
    /// Example:
    /// ```swift
    /// @FocusState private var focusedField: MyFieldType?
    ///
    /// VStack {
    ///     TextField(...)
    ///         .focused($focusedField, equals: .field1)
    ///     TextField(...)
    ///         .focused($focusedField, equals: .field2)
    /// }
    /// .keyboardToolbar(focusedField: $focusedField)
    /// ```
    func keyboardToolbar<Field: Hashable & CaseIterable>(
        focusedField: FocusState<Field?>.Binding
    ) -> some View {
        self.modifier(
            KeyboardToolbarModifier(focusedField: focusedField)
        )
    }

    /// 키보드 완료 툴바를 추가합니다.
    ///
    /// 완료 버튼만 제공하여 키보드를 내릴 수 있습니다.
    /// UUID 기반 FocusState에 사용하며, CaseIterable 제약이 없습니다.
    ///
    /// - Parameter focusedID: UUID 기반 FocusState 바인딩
    ///
    /// Example:
    /// ```swift
    /// @FocusState private var focusedMissionID: UUID?
    ///
    /// ScrollView {
    ///     ForEach(missions) { mission in
    ///         TextField(...)
    ///             .focused($focusedMissionID, equals: mission.id)
    ///     }
    /// }
    /// .keyboardDismissToolbar(focusedID: $focusedMissionID)
    /// ```
    func keyboardDismissToolbar(
        focusedID: FocusState<UUID?>.Binding
    ) -> some View {
        self.modifier(
            KeyboardDismissToolbarModifier(focusedID: focusedID)
        )
    }
}
