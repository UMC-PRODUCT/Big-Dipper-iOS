//
//  Logo.swift
//  AppProduct
//
//  Created by euijjang97 on 1/12/26.
//

import SwiftUI

struct Logo: View {
    // MARK: - Property
    
    let logoSize: CGFloat
    
    init(logoSize: CGFloat = 200) {
        self.logoSize = logoSize
    }
    
    private enum Constants {
        static let logoVspacing: CGFloat = 16
        static let logoSubtitle: String = "University MakeUs Challenge"
    }
    
    // MARK: - Body
    var body: some View {
        VStack(spacing: Constants.logoVspacing, content: {
            Image(.logoLight)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: self.logoSize)
            
            Text(Constants.logoSubtitle)
                .appFont(.title2, color: .grey900)
        })
    }
}

#Preview {
    Logo()
}

