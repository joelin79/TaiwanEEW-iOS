//
//  SlideOverCard.swift
//  TaiwanEEW
//
//  Created by 林子祐 on 2024/7/7.
//  https://gist.github.com/mshafer/7e05d0a120810a9eb49d3589ce1f6f40#file-slideovercard-swift
//
//  FROZEN — iOS 15 and 16 only. FloatingAlertCard replaces this from iOS 17 up, and all
//  new work on the alert card goes there. This is kept because it works, not because it
//  is good: the detents are fixed point values so the card takes 69% of an SE and 48% of
//  a Pro Max, PreventableScrollView never actually scrolls (canScroll is never set true),
//  and there is no drag affordance. Fix things here only if they are broken for the
//  users still on 15–16.

import SwiftUI
import MapKit

struct PreventableScrollView<Content>: View where Content: View {
    @Binding var canScroll: Bool
    var content: () -> Content
    
    var body: some View {
        if canScroll {
            ScrollView(.vertical, showsIndicators: false, content: content)
        } else {
            content()
        }
    }
}

struct SlideOverCard<Content: View>: View {
    @GestureState private var dragState = DragState.inactive
    /// Owned by the parent rather than the card, because the map behind it has to know how
    /// much of itself is covered in order to frame inside what is left.
    @Binding var position: CardPosition
    @State var canScroll: Bool

    var content: () -> Content
    var slideDirection: SlideDirection
    /// Points of the screen's bottom edge the card covers once settled. Measured after the
    /// offset is applied, which lands on safeTop + position.rawValue — the same number the
    /// map used to reconstruct for itself, now worked out by the card that causes it.
    var onSettle: (CGFloat) -> Void = { _ in }

    init(slideDirection: SlideDirection = .bottom,
         position: Binding<CardPosition>,
         onSettle: @escaping (CGFloat) -> Void = { _ in },
         @ViewBuilder content: @escaping () -> Content) {
        self.slideDirection = slideDirection
        self.content = content
        self.onSettle = onSettle
        self._position = position
        self._canScroll = State(initialValue: false)
    }
    
    var body: some View {
        let drag = DragGesture()
            .updating($dragState) { drag, state, transaction in
                // If we're at middle position and trying to drag upward
                if position == .middle && drag.translation.height < 0 {
                    // Create resistance by reducing the translation effect
                    state = .dragging(translation: CGSize(width: 0, height: drag.translation.height * 0.1))
                } else {
                    state = .dragging(translation: drag.translation)
                }
            }
            .onEnded(onDragEnded)
        
        return Group {
            VStack(spacing: 0){
                Spacer()
                    .frame(height: UIScreen.baseLine)
                if slideDirection == .bottom {
//                    Handle()
                }
                PreventableScrollView(canScroll: $canScroll){
                    self.content()
                }
                if slideDirection == .top {
//                    Handle()
                }
            }
        }
        .frame(maxHeight: .infinity)
//        .background(Color("Background"))
//        .foregroundStyle(.clear)
        .background(.ultraThickMaterial)
        .cornerRadius(10.0)
        .shadow(color: Color(.sRGBLinear, white: 0, opacity: 0.13), radius: 10.0)
        .offset(y: offsetForPosition())
        .animation(.interpolatingSpring(stiffness: 300.0, damping: 30.0, initialVelocity: 10.0), value: self.dragState.isDragging)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { report(proxy) }
                    .onChange(of: position) { _ in report(proxy) }
            }
        )
        .gesture(drag)
    }
    
    private func offsetForPosition() -> CGFloat {
        let baseOffset = self.position.rawValue
        let dragOffset = self.dragState.translation.height
        
        switch slideDirection {
        case .bottom:
            // If at middle position, don't allow movement above it (by adding resistance)
            if position == .middle && dragOffset < 0 {
                return baseOffset + (dragOffset * 2.0) // Add resistance
            }
            return baseOffset + dragOffset
        case .top:
            return -baseOffset + dragOffset
        }
    }
    
    /// Deferred a frame: at the moment position changes the view has not been laid out at
    /// its new offset yet, so reading the frame immediately returns the old one.
    private func report(_ proxy: GeometryProxy) {
        DispatchQueue.main.async {
            let top = proxy.frame(in: .global).minY
            guard top > 0 else { return }
            onSettle(max(UIScreen.screenHeight - top, 0))
        }
    }

    private func onDragEnded(drag: DragGesture.Value) {
        let verticalDirection = drag.predictedEndLocation.y - drag.location.y
        let cardTopEdgeLocation = position.rawValue + dragState.translation.height
        
        let nearestPosition = CardPosition.allCases.min(by: { abs($0.rawValue - cardTopEdgeLocation) < abs($1.rawValue - cardTopEdgeLocation) }) ?? .middle
        
        if abs(verticalDirection) > 10 {
            switch slideDirection {
            case .bottom:
                if verticalDirection > 0 {
                    position = nearestPosition.next ?? .bottom
                } else {
                    // If we're at middle, stay there
                    position = position == .middle ? .middle : nearestPosition.previous ?? .middle
                }
            case .top:
                if verticalDirection > 0 {
                    position = nearestPosition.previous ?? .bottom
                } else {
                    position = nearestPosition.next ?? .middle //.top
                }
            }
        } else {
            position = nearestPosition
        }
    }
}

enum CardPosition: CGFloat, CaseIterable {
//    case top         // most extended position
    case middle
    case bottom       // least extended position

    var rawValue: CGFloat {     // (+ downwards)
        let screenHeight = UIScreen.main.bounds.height
        switch self {
//        case .top:
//            return screenHeight - 552
        case .middle:
            return screenHeight - 457
        case .bottom:
            return screenHeight - 307
        }
    }
    
    var next: CardPosition? {
        switch self {
//        case .top: return .middle
        case .middle: return .bottom
        case .bottom: return nil
        }
    }

    var previous: CardPosition? {
        switch self {
//        case .top: return nil
        case .middle: return nil //.top
        case .bottom: return .middle
        }
    }
}

enum SlideDirection {
    case top
    case bottom
}

enum DragState {
    case inactive
    case dragging(translation: CGSize)
    
    var translation: CGSize {
        switch self {
        case .inactive:
            return .zero
        case .dragging(let translation):
            return translation
        }
    }
    
    var isDragging: Bool {
        switch self {
        case .inactive:
            return false
        case .dragging:
            return true
        }
    }
}

struct Handle: View {
    private let handleThickness = CGFloat(5.0)
    var body: some View {
        RoundedRectangle(cornerRadius: handleThickness / 2.0)
            .frame(width: 40, height: handleThickness)
            .foregroundColor(Color.secondary)
            .padding(5)
    }
}

// Preview
#Preview("EEW Detail Block"){
    SlideOverCard(slideDirection: .top, position: .constant(.middle)){
        EEWDetailBlock(eventManager: EventDispatcher(cityIndex: 0, districtIndex: 0, startListening: false))
    }
}

struct SlideOverCard_Previews: PreviewProvider {
    static var previews: some View {
        SlideOverCard(slideDirection: .bottom, position: .constant(.middle)) {
            Text("Bottom Sliding Card")
        }
    }
}
