//
//  AdaptiveLayout.swift
//  TaiwanEEW
//
//  The layout context a foldable iPhone adds.
//
//  On iPhone Duo the app moves between an outer display when the phone is closed and a
//  much larger inner display when it is open, and it can do so while running. Anything
//  that branches on `UIDevice.userInterfaceIdiom`, or that reads a screen size once, gets
//  that transition wrong: Duo is an iPhone by idiom in both poses, and its window is not
//  the same size as either display when a bar or the fold takes space.
//
//  The pose comes from the hinge, not from the reserved regions. A division region only
//  describes a fold that is inside the window, so a closed Duo — running on its outer
//  display — reports none at all and is indistinguishable from a device without a hinge.
//  `UIHingeInteraction` describes the hardware directly, and reports closed, partially
//  open and fully open whether or not the app currently spans the fold.
//
//  `AdaptiveLayoutReader` publishes the container's size and the pose. The size is
//  published even on devices without a hinge, because the rest of the app needs a live
//  container width rather than the one captured at launch.
//

import SwiftUI
import UIKit

struct AdaptiveLayout: Equatable {
    enum Posture: Equatable {
        /// Not an iPhone Duo, or iOS older than the version that describes the hinge.
        case standard
        /// Closed or partly open. The app is on the outer display, or sharing the inner
        /// one with the fold, so there is no room for the full-width card.
        case folded
        /// Fully open. The app has the whole inner display.
        case unfolded
    }

    var size: CGSize = .zero
    var posture: Posture = .standard

    var isFolded: Bool { posture == .folded }
    var isUnfolded: Bool { posture == .unfolded }
    var isDuo: Bool { posture != .standard }
}

/// Reports the container's size and, on iPhone Duo, how far the phone is open.
///
/// A background reader rather than a wrapper around the content: making the whole screen a
/// GeometryReader would change how every child is proposed a size, and the views here are
/// built around being laid out by their parent. A background leaves that layout untouched.
struct AdaptiveLayoutReader<Content: View>: View {
    @Binding var layout: AdaptiveLayout
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { apply(proxy) }
                        .onChange(of: proxy.size) { _ in apply(proxy) }
                }
            }
            .background {
                if #available(iOS 27.1, *) {
                    HingePostureReader(onChange: apply)
                        .frame(width: 1, height: 1)
                        .allowsHitTesting(false)
                }
            }
    }

    private func apply(_ proxy: GeometryProxy) {
        var updated = layout
        updated.size = proxy.size
        // The reader can be asked to update for a size change that does not alter the value
        // it publishes. Writing anyway would invalidate the parent and re-run this reader,
        // which is how this sort of observer turns into a layout loop.
        guard updated != layout else { return }
        layout = updated
    }

    @available(iOS 27.1, *)
    private func apply(_ status: UIHinge.Status) {
        let posture: AdaptiveLayout.Posture
        switch status {
        case .closed, .partiallyOpen:
            posture = .folded
        case .fullyOpen:
            posture = .unfolded
        case .unknown:
            posture = .standard
        @unknown default:
            posture = .standard
        }
        guard layout.posture != posture else { return }
        layout.posture = posture
    }
}

/// Hosts a `UIHingeInteraction` in the SwiftUI hierarchy.
///
/// The interaction is a UIKit `UIInteraction`, so it has to be attached to a view; there is
/// no SwiftUI equivalent. A one-point, non-interactive background view is enough to join
/// the hierarchy that receives hinge updates without affecting the layout.
@available(iOS 27.1, *)
private struct HingePostureReader: UIViewRepresentable {
    let onChange: (UIHinge.Status) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onChange: onChange)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear

        let interaction = UIHingeInteraction { [weak coordinator = context.coordinator] _, update in
            // Nil means this view has left a hierarchy that provides hinge updates, so
            // there is no fold to describe. It is also what a device without a hinge
            // reports on the first callback.
            guard let hinge = update.hinge else {
                coordinator?.onChange(.unknown)
                return
            }
            coordinator?.onChange(hinge.status)
        }
        view.addInteraction(interaction)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // The interaction's handler is installed once and escapes. Keeping the live closure
        // on the coordinator means a re-created SwiftUI value still reaches current state.
        context.coordinator.onChange = onChange
    }

    final class Coordinator {
        var onChange: (UIHinge.Status) -> Void

        init(onChange: @escaping (UIHinge.Status) -> Void) {
            self.onChange = onChange
        }
    }
}
