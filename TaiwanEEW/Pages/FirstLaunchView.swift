//
//  FirstLaunchView.swift
//  TaiwanEEW
//
//  Created by Joe Lin on 2023/6/8.
//

import SwiftUI

struct FirstLaunchView: View {
    
    var onDismiss: () -> Void
    @State private var isTermsAccepted = false
    
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
    var fontSize: CGFloat = 18
    
    var body: some View {
        GeometryReader { geometry in
            let maxWidth = min(geometry.size.width, 650)
            
            VStack {
                icon
                title
                content
                HStack {
                    Image(systemName: isTermsAccepted ? "checkmark.square.fill" : "square")
                        .foregroundColor(.green)
                        .font(.system(size: 26).bold())
                    
                    // Text order are different for JA due to grammatic difference
                    if let languageCode = Locale.current.languageCode, languageCode == "ja" {
                        Link(destination: URL(string: "https://docs.google.com/document/d/1R4gTmFkp3BZ2pVAdlCj4STJEB5THORklJKKZDosOcd4/edit?tab=t.0")!){
                            Text("terms-string").foregroundStyle(.blue)
                        }
                        Text("term-read-string")
                    } else {
                        Text("term-read-string")
                        Link(destination: URL(string: "https://docs.google.com/document/d/1R4gTmFkp3BZ2pVAdlCj4STJEB5THORklJKKZDosOcd4/edit?tab=t.0")!){
                            Text("terms-string").foregroundStyle(.blue)
                        }
                    }
                }
                .font(.system(size: 20).bold())
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.blue, lineWidth: 3)
                )
                .onTapGesture {
                    isTermsAccepted.toggle()
                }
                
                Text("scroll-string")
                    .font(.system(size:16))
                    .foregroundColor(Color(.systemPink))
                
                close
            }
            .frame(maxWidth: maxWidth, maxHeight: .infinity)
            .frame(maxWidth: .infinity)     // center the content
            .padding(.horizontal, 20)
            .padding(.vertical, 50)
            
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.background))
        .transition(.move(edge: .bottom))
        
    }
}

struct FirstLaunchView_Previews: PreviewProvider {
    static var previews: some View {
        FirstLaunchView(onDismiss: {})
            .environment(\.locale, .init(identifier: "zh-Hant"))
        FirstLaunchView(onDismiss: {})
            .environment(\.locale, .init(identifier: "en"))
        FirstLaunchView(onDismiss: {})
            .environment(\.locale, .init(identifier: "ja"))
    }
}


private extension FirstLaunchView {
    var icon: some View {
        Image(systemName: "rectangle.inset.filled.and.person.filled")
            .font(.system(size: 50))
            .foregroundColor(Color.blue)
    }
    
    var title: some View {
        Text("term-title-string")
            .font(
                .system(size: 45, weight: .bold, design: .rounded))
            .padding(.top, 25)
            .foregroundStyle(.primary)
    }
    
    // MARK: https://medium.com/@yeeedward/bullet-list-with-swiftui-7dfb7e3c30f1

    var content: some View {
        ScrollView {
            VStack(alignment: .leading,
                   spacing: listItemSpacing) {
                ForEach(listItems.indices, id: \.self) { idx in
                    HStack(alignment: .top) {
                        Text(toNumber(idx))
                            .font(.system(size: fontSize).bold())
                            .frame(width: bulletWidth,
                                   alignment: bulletAlignment)
                            .foregroundStyle(.primary)
                        Text(listItems[idx])
                            .font(.system(size: fontSize))
                            .frame(maxWidth: .infinity,
                                   alignment: .leading)
                            .foregroundStyle(.primary)
                    }
                }
            }.padding(.top, 20)
        }
    }
    
    var close: some View {
        Button(action: {
            onDismiss()
        }) {
            Text("dismiss-string")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(isTermsAccepted ? Color.blue : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 20)
        }
        .disabled(!isTermsAccepted)
    }
}

//// MARK: https://stackoverflow.com/questions/56760335/round-specific-corners-swiftui
//struct RoundedCorners: View {
//    var color: Color = .blue
//    var tl: CGFloat = 0.0
//    var tr: CGFloat = 0.0
//    var bl: CGFloat = 0.0
//    var br: CGFloat = 0.0
//
//    var body: some View {
//        GeometryReader { geometry in
//            Path { path in
//
//                let w = geometry.size.width
//                let h = geometry.size.height
//
//                // Make sure we do not exceed the size of the rectangle
//                let tr = min(min(self.tr, h/2), w/2)
//                let tl = min(min(self.tl, h/2), w/2)
//                let bl = min(min(self.bl, h/2), w/2)
//                let br = min(min(self.br, h/2), w/2)
//
//                path.move(to: CGPoint(x: w / 2.0, y: 0))
//                path.addLine(to: CGPoint(x: w - tr, y: 0))
//                path.addArc(center: CGPoint(x: w - tr, y: tr), radius: tr, startAngle: Angle(degrees: -90), endAngle: Angle(degrees: 0), clockwise: false)
//                path.addLine(to: CGPoint(x: w, y: h - br))
//                path.addArc(center: CGPoint(x: w - br, y: h - br), radius: br, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 90), clockwise: false)
//                path.addLine(to: CGPoint(x: bl, y: h))
//                path.addArc(center: CGPoint(x: bl, y: h - bl), radius: bl, startAngle: Angle(degrees: 90), endAngle: Angle(degrees: 180), clockwise: false)
//                path.addLine(to: CGPoint(x: 0, y: tl))
//                path.addArc(center: CGPoint(x: tl, y: tl), radius: tl, startAngle: Angle(degrees: 180), endAngle: Angle(degrees: 270), clockwise: false)
//                path.closeSubpath()
//            }
//            .fill(self.color)
//        }
//    }
//}
