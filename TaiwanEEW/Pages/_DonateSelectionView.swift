//
//  DonateSelectionView.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/8/28.
//

import SwiftUI

struct DonateSelectionView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            Capsule()
                .frame(width: 50, height: 5)
            price
        }
    }
    
    var price: some View {
        VStack(alignment: .leading){
            Text("一次性捐贈（自填金額）")
                .font(.system(size: 18).bold())
            Text("只需 20 元就可以捐贈")
            
        }
    }
}

#Preview {
    DonateSelectionView()
}
