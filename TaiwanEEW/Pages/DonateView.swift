//
//  DonateView.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/8/27.
//
///  2026/08/24 Changelog - Albert
///   - Added missing localizations for this tab 新增字串的英文及日文翻譯
///   - Fixed tab safe space which was covering the top parts of the view 修復分頁中上方空間擋到的一部分
///

import SwiftUI

struct DonateView: View {
    @Environment(\.dismiss) var dismiss
    /// Presented modally from Settings the view needs its own close and cancel controls;
    /// as a tab there is nothing to dismiss, so they are hidden.
    var showsDismissControls: Bool = true
    // Only the description used this, and it now decides by measuring rather than by
    // guessing from screen height. Kept because the layout still has fixed-size pieces
    // that may want it back.
    let smallDevice = UIScreen.screenHeight <= 667
    @State private var showDonationSheet = false

    private enum animationProperties {
        static let animationSpeed : Double = 3
        static let timerDuration : TimeInterval = 5
        static let blurRadius : CGFloat = 110
    }

    @State private var timer = Timer.publish(every: animationProperties.timerDuration, on: .main, in: .common).autoconnect()
    @StateObject private var animator = CircleAnimator(colors: GradientColors.all)

    var title: some View {
        Text("donate-view-title")
            .foregroundStyle(.white)
            .font(.system(size: 28).weight(.bold))
            .padding(.top, 25)
    }

    var description: some View {
        VStack(alignment: .leading){
            Text("donate-1-string") // ，亦無置入廣告
                .foregroundStyle(.white)
                .font(.system(size: 18))
                .padding(.top, 25)
                .padding(.horizontal, 15)
            Text("donate-2-string")
                .foregroundStyle(.white)
                .font(.system(size: 19).weight(.bold))
                .padding(.horizontal, 15)
                .padding(.top, 1)
            Text("donate-3-string")
                .foregroundStyle(.white)
                .font(.system(size: 18))
                .padding(.horizontal, 15)
                .padding(.top, 1)
        }
    }

    // Background layer only — this is the piece allowed to bleed under the
    // status bar / notch. Kept separate from content so the safe area fix
    // below doesn't accidentally clip the animated circles.
    private var animatedBackground: some View {
        ZStack {
            ForEach(animator.circles){circle in
                MovingCircle(originOffset: circle.position)
                    .foregroundStyle(circle.color)
            }
        }
        .blur(radius: animationProperties.blurRadius)
        .ignoresSafeArea()
        .clipped()
    }

    private var baseContent: some View {
        ZStack {
            // The backdrop is a sibling of the content, not a .background() of it.
            //
            // .background() sizes its content to the frame of the view it decorates. Once
            // the foreground VStack correctly stopped ignoring the safe area, that frame
            // became the safe-area inset rectangle — so the gradient and the animated
            // circles were being sized and clipped to it, leaving bars at the top and
            // bottom and cutting the animation off mid-motion. As a ZStack layer the
            // backdrop is sized by the ZStack instead, and reaches the screen edges.
            ZStack {
                GradientColors.backgroundColor
                animatedBackground
            }
            .ignoresSafeArea()

            // Content stays inside the safe area, which is what Albert's change set out to
            // fix: before it, the close button and app icon sat under the status bar.
            VStack(spacing: 0){
                HStack {
                    if showsDismissControls {
                        Button {
                            dismiss.callAsFunction()
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.white)
                                .font(.title2.bold())
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                        }
                    }
                    Spacer()
                }
                // No manual top padding needed anymore — this HStack lives inside
                // a VStack that does NOT ignore the safe area, so SwiftUI keeps
                // it clear of the status bar / notch on its own.

                HStack(spacing: 0) {
                    Image("Icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .if(UIScreen.isZoomed) { view in
                            view.frame(width: 75, height: 75)
                        }
                        .if(!UIScreen.isZoomed) { view in
                            view.frame(width: 100, height: 100)
                        }

                }


                title

                // Scrolls only when the text does not fit, which is the actual condition.
                //
                // This was originally gated on smallDevice || UIScreen.isZoomed, a proxy
                // calibrated when the copy existed only in Chinese. The English translation
                // is about four times longer — 608 characters against 155 — so on a
                // full-size phone it was truncated mid-sentence.
                //
                // An unconditional ScrollView fixes that but breaks the other direction: a
                // ScrollView is greedy, taking all the height it is offered, so with the
                // short Chinese copy it swallowed the space the Spacers below use to
                // distribute the coins and buttons, leaving a gap under the text.
                //
                // ViewThatFits picks the first child that fits, so Chinese gets the plain
                // self-sizing VStack and the Spacers behave as before, while English and
                // Japanese fall through to the scrolling version.
                if #available(iOS 16.0, *) {
                    ViewThatFits(in: .vertical) {
                        description
                        ScrollView { description }
                    }
                } else {
                    // ViewThatFits is iOS 16+. Below that, prefer scrolling: a slightly
                    // loose layout beats a sentence cut in half.
                    ScrollView { description }
                }

                Spacer()

                HStack(alignment: .firstTextBaseline, spacing: 0){

                    Image("coin")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .frame(width: 75, height: 100)

                    Image("coin")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(RoundedRectangle(cornerRadius: 30))
                        .frame(width: 25, height: 100)

                    RoundedRectangle(cornerRadius: 5.0)
                        .overlay {
                            Image(systemName: "gift.fill")
                                .font(.system(size: 23))
                                .foregroundStyle(.black)
                        }
                        .frame(width: 35, height: 35)
                        .foregroundStyle(.cyan)
                        .offset(x:15)
                }
                .frame(width: 175)
                Spacer()

                HStack(alignment: .top, spacing: UIScreen.isZoomed ? 25 : 50){

                    if showsDismissControls {
                        HStack {
                            Button {
                                dismiss.callAsFunction()
                            } label: {
                                ActionButtonLabel(
                                    title: "cancel-string".localized,
                                    fallbackFill: Color(uiColor: .darkGray),
                                    glassTint: nil,
                                    fallbackStroke: nil
                                )
                            }
                        }
                    }

                    HStack {
                        VStack {
                            Button{
                                showDonationSheet = true
                            } label: {
                                ActionButtonLabel(
                                    title: "donate-view-cta-string".localized,
                                    fallbackFill: Color(red: 36/255, green: 86/255, blue: 156/255),
                                    glassTint: Color(red: 36/255, green: 86/255, blue: 156/255),
                                    fallbackStroke: Color(red: 116/255, green: 140/255, blue: 173/255)
                                )
                            }
                            Text("donate-view-cta-min")
                                .font(.system(size: 14).bold())
                                .foregroundStyle(.white)
                        }
                    }
                }

                Spacer()
                Spacer()
            }
        }
        .onDisappear{
            timer.upstream.connect().cancel()
        }
        .onAppear{
            animateCircles()
            timer = Timer.publish(every: animationProperties.timerDuration, on: .main, in: .common)
                .autoconnect()
        }
        .onReceive(timer) { _ in
            animateCircles()
        }
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                baseContent
                    .modifier(DonationPresentationModifier(isPresented: $showDonationSheet))
            }
            .toolbar(.hidden, for: .navigationBar)
        } else {
            baseContent
                .fullScreenCover(isPresented: $showDonationSheet) {
                    DonationOptionsSheet()
                }
        }
    }

    private func animateCircles(){
        withAnimation(.easeInOut(duration: animationProperties.animationSpeed)){
            animator.animate()
        }
    }
}

// The donation options are shown as a whole page instead of a sheet on every
// iOS version: on iOS 26.x (confirmed up to 26.5) a SwiftUI regression causes
// sheets to be dismissed immediately when the parent view re-renders during
// presentation, so sheets are avoided entirely for this flow.
@available(iOS 16.0, *)
private struct DonationPresentationModifier: ViewModifier {
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.navigationDestination(isPresented: $isPresented) {
            DonationOptionsSheet()
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

// Liquid Glass button label on iOS 26+, solid rounded rectangle on older versions.
// A nil glassTint gives clear (untinted) glass for the secondary action.
private struct ActionButtonLabel: View {
    let title: String
    let fallbackFill: Color
    let glassTint: Color?
    let fallbackStroke: Color?

    var body: some View {
        if #available(iOS 26.0, *) {
            label
                .glassEffect(glass, in: .rect(cornerRadius: 10))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .frame(width: 140, height: 50)
                    .foregroundStyle(fallbackFill)
                    .overlay {
                        if let fallbackStroke {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(fallbackStroke, lineWidth: 1)
                        }
                    }
                label
            }
        }
    }

    private var label: some View {
        Text(title)
            .font(.system(size: 18).bold())
            .foregroundStyle(.white)
            .lineLimit(1)
            // The 140pt frame was sized for 支持贊助. "Give Support" and 支援・スポンサー do
            // not fit at 18pt and were being truncated to an ellipsis, which on a button
            // is worse than smaller type — "Give Supp…" does not say what it does.
            // Scaling keeps both buttons the same width, which the side-by-side layout
            // and the fallback RoundedRectangle below both depend on.
            .minimumScaleFactor(0.6)
            .frame(width: 140, height: 50)
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var glass = Glass.regular
        if let glassTint {
            glass = glass.tint(glassTint)
        }
        return glass.interactive()
    }
}

#Preview {
    DonateView()
}

private enum GradientColors {
    static var all : [Color] {
        [
            Color(red: 92/255, green: 0/255, blue: 0/255),
            Color(red: 206/255, green: 81/255, blue: 77/255),
            Color(red: 158/255, green: 11/255, blue: 11/255),
            Color(red: 215/255, green: 111/255, blue: 111/255),
            Color(red: 191/255, green: 111/255, blue: 61/255)

        ]
    }
    static var backgroundColor : Color {
        Color(red: 158/255, green: 29/255, blue: 3/255)
    }
}

private struct MovingCircle: Shape {
    var originOffset : CGPoint
    var animatableData: CGPoint.AnimatableData{
        get{
            originOffset.animatableData
        }
        set{
            originOffset.animatableData = newValue
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let adjustedX = rect.width * originOffset.x
        let adjustedY = rect.width * originOffset.y
        let smallestDimension = min(rect.width, rect.height)

        path.addArc(center: CGPoint(x: adjustedX, y: adjustedY), radius: smallestDimension/2, startAngle: .zero, endAngle: .degrees(360), clockwise: true)

        return path
    }
}

private class CircleAnimator: ObservableObject{
    class Circle : Identifiable {
        internal init(position: CGPoint, color: Color){
            self.position = position
            self.color = color
        }
        var position : CGPoint
        let id = UUID().uuidString
        let color : Color
    }

    @Published private(set) var circles : [Circle] = []

    init(colors:[Color]) {
        circles = colors.map({color in
            Circle(position: CircleAnimator.generateRandomPosition(), color: color)
        })
    }

    func animate() {
        objectWillChange.send()
        for circle in circles {
            circle.position = CircleAnimator.generateRandomPosition()
        }
    }

    static func generateRandomPosition() -> CGPoint {
        CGPoint(x: CGFloat.random(in: 0...1), y: CGFloat.random(in: 0...2))
    }
}
