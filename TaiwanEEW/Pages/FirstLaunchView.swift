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

    // Twice the default speed for the two buttons' colour changes on accept.
    private let acceptFade: Animation = .easeInOut(duration: 0.15)

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

    // Fixed .system(size:) fonts ignore Dynamic Type; @ScaledMetric scales these bases with
    // the user's text-size setting (the overflow/scroll logic then handles the taller list).
    @ScaledMetric(relativeTo: .body) private var listFontSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var cardFontSize: CGFloat = 17
    @ScaledMetric(relativeTo: .title3) private var cardIconSize: CGFloat = 24
    @ScaledMetric(relativeTo: .body) private var buttonFontSize: CGFloat = 20
    @ScaledMetric(relativeTo: .largeTitle) private var titleFontSize: CGFloat = 34
    @ScaledMetric(relativeTo: .largeTitle) private var iconFontSize: CGFloat = 40
    @ScaledMetric(relativeTo: .largeTitle) private var iconFrameHeight: CGFloat = 46

    var body: some View {
        GeometryReader { geometry in
            let maxWidth = min(geometry.size.width, 650)
            
            VStack {
                icon
                title
                termsRegion
                termsAcceptance
                    .padding(.top, 8)
                close
            }
            .frame(maxWidth: maxWidth, maxHeight: .infinity)
            .frame(maxWidth: .infinity)     // center the content
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 20)

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


// Carries the terms list's intrinsic height up to the region, read in the same layout pass
// via overlayPreferenceValue so scroll sizing/affordances need no state round-trip.
private struct TermsContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private extension FirstLaunchView {
    var icon: some View {
        Image(systemName: "rectangle.inset.filled.and.person.filled")
            .font(.system(size: iconFontSize))
            .foregroundColor(Color.blue)
            // Height tracks the icon size (both scale with Dynamic Type) so the title sits
            // just below it. Matches the onboarding page's icon at the default text size.
            .frame(height: iconFrameHeight)
    }
    
    var title: some View {
        Text("term-title-string")
            .font(
                .system(size: titleFontSize, weight: .bold, design: .rounded))
            .padding(.top, 8)
            .foregroundStyle(.primary)
    }
    
    // MARK: https://medium.com/@yeeedward/bullet-list-with-swiftui-7dfb7e3c30f1

    /// The flexible terms area. A hidden copy reports the list's intrinsic height; that
    /// value is read back in the SAME layout pass (overlayPreferenceValue), so we can decide
    /// synchronously whether the list overflows the space it's been given. When it fits, the
    /// area is sized exactly to the content and cannot scroll. When it doesn't, it's capped
    /// to the available height and gains a bordered frame, a bottom fade, a scroll indicator,
    /// and the "scroll for more" hint — so it's obvious there's more to read.
    var termsRegion: some View {
        GeometryReader { proxy in
            let available = proxy.size.height

            ZStack { termsMeasurer }                          // publishes intrinsic height
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .overlayPreferenceValue(TermsContentHeightKey.self) { contentH in
                    let scrollable = contentH > available + 1
                    let hintHeight: CGFloat = scrollable ? 26 : 0
                    // Unmeasured (contentH == 0) → fill the space so the list is never blank;
                    // fits → size to content (no scroll range); overflows → cap and scroll.
                    let scrollAreaHeight: CGFloat = contentH <= 0
                        ? available
                        : (scrollable ? max(available - hintHeight, 0) : contentH)

                    VStack(spacing: 4) {
                        ZStack(alignment: .bottom) {
                            ScrollView(.vertical, showsIndicators: scrollable) {
                                termsList
                                    .padding(.horizontal, scrollable ? 12 : 0)
                            }
                            .frame(height: scrollAreaHeight)

                            if scrollable {
                                LinearGradient(
                                    colors: [Color(.background).opacity(0), Color(.background)],
                                    startPoint: .top, endPoint: .bottom
                                )
                                .frame(height: 32)
                                .allowsHitTesting(false)
                            }
                        }
                        // A rounded border only when scrollable, so the area reads as a
                        // contained, scrollable box rather than free-floating text.
                        .overlay {
                            if scrollable {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color(.separator), lineWidth: 1)
                            }
                        }

                        if scrollable { scrollHint }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
        }
    }

    /// Hidden, height-unconstrained copy of the list that reports its INTRINSIC height, so
    /// overflow is judged by what the list *wants*, not the space it's squeezed into.
    var termsMeasurer: some View {
        termsList
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(GeometryReader { g in
                Color.clear.preference(key: TermsContentHeightKey.self, value: g.size.height)
            })
            .opacity(0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// The numbered terms list, sized to its content.
    var termsList: some View {
        VStack(alignment: .leading,
               spacing: listItemSpacing) {
            ForEach(listItems.indices, id: \.self) { idx in
                HStack(alignment: .top) {
                    Text(toNumber(idx))
                        .font(.system(size: listFontSize).bold())
                        .frame(width: bulletWidth,
                               alignment: bulletAlignment)
                        .foregroundStyle(.primary)
                    Text(listItems[idx])
                        .font(.system(size: listFontSize))
                        .frame(maxWidth: .infinity,
                               alignment: .leading)
                        .foregroundStyle(.primary)
                }
            }
        }.padding(.top, 20)
    }

    /// Shown only while the list overflows: a quiet nudge that there's more to read below.
    var scrollHint: some View {
        Label("scroll-string", systemImage: "chevron.down")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.top, 6)
    }

    // Terms gate: a single tappable card whose whole surface toggles acceptance. Replaces
    // the old blue-outlined box + pink text, which read as an error state rather than a
    // control. The scroll hint now lives above this card, only while the list overflows.
    var termsAcceptance: some View {
        // Center-align so the checkbox sits vertically centered against the label, which is a
        // single continuous Text that wraps to as many lines as it needs.
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isTermsAccepted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: cardIconSize))
                .foregroundStyle(isTermsAccepted ? Color.green : Color.secondary)

            termsText
                .font(.system(size: cardFontSize, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isTermsAccepted
                      ? Color.green.opacity(0.12)
                      : Color(.secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isTermsAccepted
                              ? Color.green.opacity(0.5)
                              : Color(.separator),
                              lineWidth: 1)
        )
        // Whole card is the tap target; the inline link still opens the terms.
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            withAnimation(acceptFade) { isTermsAccepted.toggle() }
        }
        .animation(acceptFade, value: isTermsAccepted)
    }

    /// One continuous, wrapping sentence with the terms name as an inline tappable link
    /// (built from Markdown) so the text flows as a paragraph rather than separate pieces.
    /// Order differs for JA due to a grammatical difference.
    var termsText: some View {
        let url = "https://docs.google.com/document/d/1R4gTmFkp3BZ2pVAdlCj4STJEB5THORklJKKZDosOcd4/edit?tab=t.0"
        let read = NSLocalizedString("term-read-string", comment: "")
        let name = NSLocalizedString("terms-string", comment: "")
        // The ↗ sits inside the link text so it stays attached and inline.
        let link = "[\(name) ↗](\(url))"
        let isJA = Locale.current.languageCode == "ja"
        let sentence = isJA ? "\(link) \(read)" : "\(read) \(link)"

        return Text(attributedTerms(sentence))
            .tint(.blue)
            .foregroundStyle(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Parses the Markdown sentence (with its inline link) into an AttributedString.
    func attributedTerms(_ markdown: String) -> AttributedString {
        (try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(markdown)
    }

    var close: some View {
        Button(action: {
            onDismiss()
        }) {
            Text("dismiss-string")
                .font(.system(size: buttonFontSize, weight: .bold))
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(closeBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.top, 6)
        }
        .disabled(!isTermsAccepted)
        .animation(acceptFade, value: isTermsAccepted)
    }

    /// Liquid Glass on iOS 26+ with the identical solid fill below it, mirroring the
    /// onboarding page's continue button so the two screens' buttons match.
    @ViewBuilder
    var closeBackground: some View {
        let tint: Color = isTermsAccepted ? .blue : .gray
        if #available(iOS 26.0, *) {
            tint.glassEffect(.regular.tint(tint).interactive(),
                             in: .rect(cornerRadius: 16))
        } else {
            tint
        }
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
