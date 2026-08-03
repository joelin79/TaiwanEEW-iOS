//
//  InformationView.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/7/12.
//

import SwiftUI

struct InformationView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading){
                VStack(alignment: .leading) {
                    Text("mechanics-title-string")
                        .font(.title.bold())
                        .padding(.bottom, 2)
                        .foregroundColor(.blue)
                    Text("mechanics-string")
                }.padding(.bottom,10)
                VStack(alignment: .leading) {
                    Text("sources-title-string")
                        .font(.title2.bold())
                        .padding(.bottom, 2)
                        .padding(.top, 3)
                        .foregroundColor(.blue)
                    Text("sources-string")
                }
            }
            .padding()
        }
        
    }
}

struct InformationView_Previews: PreviewProvider {
    static var previews: some View {
        InformationView()
    }
}
