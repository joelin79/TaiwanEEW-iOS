//
//  FloatingAlertCard.swift
//  TaiwanEEW
//
//  The alert card on iOS 17 and later. SlideOverCard remains for 15–16 and is frozen —
//  see the note at the top of that file.
//
//  Two differences from the old card matter, and the first forces the second:
//
//  It is sized, not offset. SlideOverCard is a full-height view pushed down the screen,
//  so its bottom edge always sits below the display: there is nothing to inset from the
//  bottom and no bottom corners to round. This one has an explicit height and grows or
//  shrinks between two detents, which is what allows the floating inset look.
//
//  Its height comes from measuring the content rather than from constants. The old card
//  is 457pt tall on every device — 69% of an SE and 48% of a Pro Max — which is why the
//  map had so much less to work with on small phones.
//

import SwiftUI

@available(iOS 17.0, *)
struct FloatingAlertCard<Expanded: View, Compact: View>: View {
    @Binding var position: CardPosition

    /// Points of the screen's bottom edge the card covers, reported once it settles.
    ///
    /// Measured from the card's own frame rather than derived from the position, so it
    /// already accounts for the margins, the tab bar and the home indicator. This is what
    /// the map frames around; see AlertMapView.mapInsets.
    var onSettle: (CGFloat) -> Void

    @ViewBuilder var expanded: Expanded
    @ViewBuilder var compact: Compact

    /// The reset transaction is not decoration. When the gesture ends, @GestureState
    /// reverts to 0 in a transaction of its own; left empty that revert is unanimated, so
    /// a small drag that releases back onto the detent it started from snaps rather than
    /// settling — and that is the common outcome of exactly the slow drags being complained
    /// about, since `position = target` assigns an equal value and animates nothing.
    @GestureState(resetTransaction: Transaction(animation: .snappy(duration: 0.32, extraBounce: 0.02)))
    private var dragTranslation: CGFloat = 0
    @State private var contentHeights: [CardPosition: CGFloat] = [:]
    /// Read off the enclosing GeometryReader's proxy rather than measured from the card.
    /// An earlier version probed the card's own frame, which made the card's height an
    /// input to the value determining the card's height — a real layout feedback loop.
    ///
    /// Only the overhang is held in state, because settledObscuredHeight is read outside
    /// the GeometryReader. The width is passed down as a parameter: held in state it would
    /// start at 0, and that first pass would measure both layouts at zero width and seed
    /// contentHeights from wrapped text.
    @State private var bottomOverhang: CGFloat = 0

    // MARK: - Metrics

    /// Margins on the three sides the card touches. The corner radius is set to sit
    /// roughly concentric with the display's own curve once the side margin is taken off:
    /// modern iPhones are near 55pt, so ~44 reads as parallel rather than arbitrary.
    /// There is no public API for the real display radius — UIScreen._displayCornerRadius
    /// is private and not worth shipping for this.
    private static var horizontalMargin: CGFloat { 10 }
    private static var bottomMargin: CGFloat { 10 }
    private static var cornerRadius: CGFloat { 44 }

    /// Handle to the first row of content, and the last block down to the tab bar. Its own
    /// value rather than AlertBlockMetrics.edgeInset: the vertical gaps sit against the
    /// handle and the tab bar, which already carry their own visual weight, so they read
    /// heavier than the same number does at the sides.
    private static var contentGap: CGFloat { 16 }
    /// Handle, its own top margin, and the gap below it.
    private static var grabberArea: CGFloat { 8 + 5 + contentGap }
    private static var contentBottomPadding: CGFloat { contentGap }

    /// Used only for the first layout pass, before the content has been measured. Wrong
    /// on any given device, but only ever visible for a single frame, and a wrong height
    /// for one frame beats a zero-height card that pops open.
    private static func fallbackContentHeight(_ position: CardPosition) -> CGFloat {
        position == .middle ? 400 : 96
    }

    /// Deliberately low bounce. The old card fed a hardcoded initialVelocity of 10 into
    /// its spring, which is what made it overshoot on both directions of travel. Velocity
    /// belongs in choosing *which* detent to land on, not in how hard the card hits it.
    private static var settle: Animation { .snappy(duration: 0.32, extraBounce: 0.02) }

    // MARK: - Geometry

    private func contentHeight(_ position: CardPosition) -> CGFloat {
        contentHeights[position] ?? Self.fallbackContentHeight(position)
    }

    /// The overhang is added to the height rather than used as padding, because the card
    /// is bottom-anchored and its content is top-aligned: extending the height grows the
    /// card downward past the tab bar while leaving the content where it was. That is the
    /// Flighty arrangement — the card reaches the screen edge and the tab bar floats on
    /// top of it, instead of the card stopping short above the bar.
    private func cardHeight(_ position: CardPosition) -> CGFloat {
        Self.grabberArea + contentHeight(position) + Self.contentBottomPadding + overhangExtra
    }

    /// How far past the safe area the card has to reach to touch the screen edge.
    private var overhangExtra: CGFloat { max(bottomOverhang - Self.bottomMargin, 0) }

    /// The room left for content at the card's current height. Derived from currentHeight
    /// so it moves continuously with the finger — framing it to whichever detent is
    /// showing made it jump by the difference between the two layouts at the halfway
    /// point, which is the lurch seen when the layouts trade places.
    private var contentAreaHeight: CGFloat {
        max(currentHeight - Self.grabberArea - Self.contentBottomPadding - overhangExtra, 0)
    }

    private var expandedHeight: CGFloat { cardHeight(.middle) }
    private var compactHeight: CGFloat { cardHeight(.bottom) }

    /// Dragging up is a negative translation and should grow the card, hence the subtract.
    /// Past either detent the movement is damped rather than blocked, so the card resists
    /// instead of hitting a wall — the old card only did this at one end, and by doubling
    /// the translation rather than shrinking it.
    ///
    /// Takes the translation as an argument rather than reading dragTranslation, because
    /// @GestureState resets the moment the gesture ends: onEnded needs the height the card
    /// was released at, and reading the state there gives the settled height instead. That
    /// made the release almost always project back onto the detent it started from, so the
    /// card would barely ever change state.
    private func height(forTranslation translation: CGFloat) -> CGFloat {
        let raw = cardHeight(position) - translation
        if raw > expandedHeight { return expandedHeight + (raw - expandedHeight) * 0.25 }
        if raw < compactHeight { return compactHeight - (compactHeight - raw) * 0.25 }
        return raw
    }

    private var currentHeight: CGFloat { height(forTranslation: dragTranslation) }

    /// 0 at the compact detent, 1 at the expanded one. Used only to decide which layout
    /// is showing, not to fade between them.
    private var progress: Double {
        let range = expandedHeight - compactHeight
        guard range > 0 else { return position == .middle ? 1 : 0 }
        return min(max((currentHeight - compactHeight) / range, 0), 1)
    }

    /// Held in state with a dead band rather than computed as `progress > 0.5`. A bare
    /// threshold has no hysteresis, so parking the finger near the midpoint — which is what
    /// a slow drag does — lets sub-point tremor flip it back and forth, swapping two very
    /// different layouts several times a second.
    @State private var showsExpanded = true

    // MARK: - Body

    var body: some View {
        GeometryReader { proxy in
            card(width: max(proxy.size.width - Self.horizontalMargin * 2, 0))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, Self.bottomMargin)
                .ignoresSafeArea(edges: .bottom)
                .onAppear { bottomOverhang = proxy.safeAreaInsets.bottom }
                .onChange(of: proxy.safeAreaInsets.bottom) { _, new in bottomOverhang = new }
        }
        // Merged, not replaced. Both layouts publish, and a pass where one is missing must
        // not drop the other back to its fallback.
        .onPreferenceChange(ContentHeightKey.self) { contentHeights.merge($0) { _, new in new } }
        // The dead band: past 0.55 going up, past 0.45 coming down. Between the two the
        // layout stays as it is, so a finger resting near the midpoint cannot chatter.
        .onChange(of: progress) { _, p in
            if p > 0.55 { showsExpanded = true }
            else if p < 0.45 { showsExpanded = false }
        }
        .onAppear {
            showsExpanded = position == .middle
            onSettle(settledObscuredHeight)
        }
        .onChange(of: position) { _, new in
            showsExpanded = new == .middle
        }
        .onChange(of: settledObscuredHeight) { _, new in onSettle(new) }
    }

    private func card(width: CGFloat) -> some View {
        VStack(spacing: 0) {
            grabber
            contentStack
            Spacer(minLength: 0)
        }
        // Width and height both fixed here, ahead of the clip. Applying the width outside
        // the clipShape only relabels the size: the shape has already been cut at whatever
        // width an incompressible child forced, so the excess still draws over the margins.
        // Stated, not measured. The content cannot work its own width out without the
        // answer depending on what it decides to draw — see CardContentWidthKey.
        .environment(\.cardContentWidth, width)
        .frame(width: width, height: currentHeight, alignment: .top)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous)
                .fill(.ultraThickMaterial)
                // On the shape, not on the finished card: applied after the clip it is
                // derived from the composited alpha mask of a material blur, recomputed
                // on every frame the height changes.
                .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.13), radius: 10)
        )
        .clipShape(RoundedRectangle(cornerRadius: Self.cornerRadius, style: .continuous))
        // No implicit .animation here on purpose. position only ever changes inside the
        // withAnimation in onEnded, so an implicit modifier adds nothing — and one whose
        // animation argument is recomputed every frame of the drag is pure churn.
        .gesture(drag)
    }

    /// The affordance the old card never had — Handle() existed but was commented out at
    /// both call sites, so nothing indicated the card moved.
    private var grabber: some View {
        Capsule()
            .fill(Color.secondary.opacity(0.5))
            .frame(width: 36, height: 5)
            .padding(.top, 8)
            .padding(.bottom, Self.contentGap)
    }

    /// Both layouts stay mounted and trade places on opacity. An if/else here swaps the
    /// view identity mid-drag, so SwiftUI tears one down and inserts the other at exactly
    /// the moment the finger is moving — visible as a hitch.
    ///
    /// The stack is then framed to whichever layout is showing. Leaving it unframed makes
    /// it permanently as tall as the expanded content, which is what put the compact row
    /// outside the collapsed card.
    ///
    /// fixedSize on the vertical axis is load-bearing, not tidying. The card imposes a
    /// height here, so without it a greedy Spacer inside the content — and EEWDetailBlock
    /// has one — would expand to whatever height was offered, which is itself derived from
    /// the measurement. Measured height would then depend on imposed height and vice versa.
    private var contentStack: some View {
        ZStack(alignment: .top) {
            expanded
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .background(heightReader(for: .middle))
                .opacity(showsExpanded ? 1 : 0)
            compact
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .background(heightReader(for: .bottom))
                .opacity(showsExpanded ? 0 : 1)
        }
        .frame(height: contentAreaHeight, alignment: .top)
        .clipped()
    }

    private func heightReader(for position: CardPosition) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(key: ContentHeightKey.self,
                                   value: [position: proxy.size.height])
        }
    }

    // MARK: - Gesture

    private var drag: some Gesture {
        // .global, not the default .local. This gesture is attached to the card, and the
        // card's layout frame is bottom-anchored — so growing its height moves its origin
        // up. In local space the translation is then measured against a space the card is
        // itself moving, feeding the card's own response back into the gesture's input.
        // That is an undamped two-frame oscillation of about half the drag distance:
        // masked by real motion on a fast flick, pure flicker on a slow drag. The old card
        // never showed it because .offset moves the rendering, not the layout frame.
        //
        // minimumDistance 0 because the default of 10 is reported as an immediate 10pt of
        // translation, which this maps straight to height — a visible pop at the start of
        // every drag, again only noticeable when nothing else is moving.
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                // Velocity as the tail of the predicted throw, the same shape SlideOverCard
                // used, but applied to project where the drag was heading rather than to
                // kick the spring.
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let released = height(forTranslation: value.translation.height)
                let projected = released - velocity
                let target: CardPosition =
                    abs(projected - expandedHeight) < abs(projected - compactHeight)
                    ? .middle : .bottom

                // Swapped inside the same animation as the position. Driving it from
                // progress instead would flip it on the first frame, while the frame is
                // still interpolating — leaving the expanded layout inside a card that is
                // still compact for the length of the spring.
                withAnimation(Self.settle) {
                    position = target
                    showsExpanded = target == .middle
                }
            }
    }

    /// The card's bottom edge sits one margin above the screen, so what it covers is just
    /// its height plus that margin. Derived rather than measured: reading the real frame
    /// meant a preference write on every frame of the drag, and since preferences resolve
    /// after layout that bought an extra layout pass per frame, one frame stale.
    ///
    /// Every input here holds still during a drag, so this changes only when the card
    /// actually settles somewhere new or the content resizes.
    private var settledObscuredHeight: CGFloat {
        cardHeight(position) + Self.bottomMargin
    }
}

// MARK: - Preferences

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: [CardPosition: CGFloat] = [:]
    static func reduce(value: inout [CardPosition: CGFloat],
                       nextValue: () -> [CardPosition: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}
