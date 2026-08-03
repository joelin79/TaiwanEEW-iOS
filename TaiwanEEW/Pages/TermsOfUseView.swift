//
//  TermsOfUseView.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/7/12.
//

import SwiftUI

struct TermsOfUseView: View {
    // MARK: https://medium.com/@yeeedward/bullet-list-with-swiftui-7dfb7e3c30f1
    var listItems = [
        NSLocalizedString("term1-string", comment: ""),
        NSLocalizedString("term2-string", comment: ""),
        NSLocalizedString("term3-string", comment: ""),
        NSLocalizedString("term4-string", comment: "")
    ]
    var listItemSpacing: CGFloat? = 18
    var toNumber: ((Int) -> String) = { "\($0 + 1)." }
    var bulletWidth: CGFloat? = nil
    var bulletAlignment: Alignment = .leading
    var fontSize: CGFloat = 20
    
    var body: some View {
        ScrollView {
            VStack {
                content
                    .padding()
            }
            .padding(.vertical)
        }
    }
    
    var content: some View {
        VStack(alignment: .leading,
               spacing: listItemSpacing) {
            ForEach(listItems.indices, id: \.self) { idx in
                HStack(alignment: .top) {
                    Text(toNumber(idx))
                        .font(.system(size: fontSize))
                        .frame(width: bulletWidth,
                               alignment: bulletAlignment)
                    Text(listItems[idx])
                        .font(.system(size: fontSize))
                        .frame(maxWidth: .infinity,
                               alignment: .leading)
                }
            }
        }
    }
}

struct TermsOfUseView_Previews: PreviewProvider {
    static var previews: some View {
        TermsOfUseView()
    }
}
