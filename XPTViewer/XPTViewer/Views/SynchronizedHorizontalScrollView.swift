import SwiftUI
import Combine

final class HorizontalScrollState: ObservableObject {
    @Published var offset: CGFloat = 0
    fileprivate var isUpdatingProgrammatically = false
}

struct SynchronizedHorizontalScrollView<Content: View>: View {
    @ObservedObject private var state: HorizontalScrollState
    private let showsIndicators: Bool
    private let contentBuilder: () -> Content

    init(state: HorizontalScrollState, showsIndicators: Bool = false, @ViewBuilder content: @escaping () -> Content) {
        _state = ObservedObject(wrappedValue: state)
        self.showsIndicators = showsIndicators
        self.contentBuilder = content
    }

    var body: some View {
        Representable(state: state, showsIndicators: showsIndicators, contentBuilder: contentBuilder)
    }
}

#if os(macOS)
import AppKit

private struct Representable<Content: View>: NSViewRepresentable {
    @ObservedObject var state: HorizontalScrollState
    let showsIndicators: Bool
    let contentBuilder: () -> Content

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = showsIndicators
        scrollView.horizontalScrollElasticity = .automatic
        scrollView.verticalScrollElasticity = .none
        if showsIndicators {
            scrollView.autohidesScrollers = false
            scrollView.scrollerStyle = .legacy
        }

        let hostingView = context.coordinator.hostingView
        hostingView.rootView = AnyView(contentBuilder())

        scrollView.documentView = hostingView

        context.coordinator.installConstraints(on: hostingView, in: scrollView)
        
        // CRITICAL: Set scroll position BEFORE starting observation and BEFORE view becomes visible
        // This prevents the visual glitch where rows appear at column 0 before adjusting
        let targetOffset = state.offset
        
        // Force immediate layout and scroll position before view is displayed
        scrollView.layoutSubtreeIfNeeded()
        scrollView.contentView.scroll(to: NSPoint(x: targetOffset, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        
        // Ensure the scroll position is locked before the view becomes visible
        // Use a synchronous layout pass to prevent any visible reset
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0
            context.allowsImplicitAnimation = false
        }) {
            scrollView.contentView.scroll(to: NSPoint(x: targetOffset, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
        
        // Now start observing - the view is already at the correct position
        context.coordinator.startObserving(scrollView: scrollView)
        
        // Verify and correct after layout completes (but view should already be correct)
        DispatchQueue.main.async {
            context.coordinator.updateScrollPositionIfNeeded(scrollView: scrollView, targetOffset: targetOffset)
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        // CRITICAL: Preserve scroll position BEFORE updating content
        // Updating rootView can cause the scroll view to reset, so we must restore immediately
        let preservedOffset = nsView.contentView.bounds.origin.x
        let targetOffset = state.offset != 0 ? state.offset : preservedOffset
        
        // Update content
        context.coordinator.hostingView.rootView = AnyView(contentBuilder())
        context.coordinator.scrollView = nsView
        
        // Immediately restore scroll position synchronously to prevent visible reset
        // Use NSAnimationContext to ensure the position is set before the view updates
        NSAnimationContext.runAnimationGroup({ animationContext in
            animationContext.duration = 0
            animationContext.allowsImplicitAnimation = false
        }) {
            nsView.contentView.scroll(to: NSPoint(x: targetOffset, y: 0))
            nsView.reflectScrolledClipView(nsView.contentView)
        }
        
        // Double-check after view update completes to ensure it sticks
        DispatchQueue.main.async {
            context.coordinator.updateScrollPositionImmediately(scrollView: nsView, targetOffset: targetOffset)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    final class Coordinator: NSObject {
        let state: HorizontalScrollState
        let hostingView: NSHostingView<AnyView>
        private var observation: NSObjectProtocol?
        private var cancellable: AnyCancellable?
        weak var scrollView: NSScrollView?
        private var isDeallocating = false

        init(state: HorizontalScrollState) {
            self.state = state
            self.hostingView = NSHostingView(rootView: AnyView(EmptyView()))
            super.init()

            cancellable = state.$offset.sink { [weak self] newOffset in
                guard let self, let scrollView = self.scrollView else { return }
                // CRITICAL: Update immediately for synchronous synchronization
                // @Published properties notify on the main thread, so we're already on main
                // Update immediately without any async delay to keep all rows perfectly aligned
                self.updateScrollPositionImmediately(scrollView: scrollView, targetOffset: newOffset)
            }
        }

        func installConstraints(on hostingView: NSHostingView<AnyView>, in scrollView: NSScrollView) {
            hostingView.translatesAutoresizingMaskIntoConstraints = false

            let contentView = scrollView.contentView

            hostingView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            hostingView.topAnchor.constraint(equalTo: contentView.topAnchor).isActive = true
            hostingView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor).isActive = true
            hostingView.heightAnchor.constraint(equalTo: scrollView.heightAnchor).isActive = true
        }

        func startObserving(scrollView: NSScrollView) {
            if let observation {
                NotificationCenter.default.removeObserver(observation)
                self.observation = nil
            }
            self.scrollView = scrollView
            scrollView.contentView.postsBoundsChangedNotifications = true
            observation = NotificationCenter.default.addObserver(
                forName: NSView.boundsDidChangeNotification,
                object: scrollView.contentView,
                queue: .main
            ) { [weak self] notification in
                guard let self, !self.isDeallocating else { return }
                // Check if scrollView is still valid (not deallocated)
                guard let scrollView = self.scrollView,
                      scrollView.contentView == notification.object as? NSClipView,
                      scrollView.window != nil else { return }
                if state.isUpdatingProgrammatically { return }
                
                var newOffset = scrollView.contentView.bounds.origin.x
                let currentStateOffset = state.offset
                
                // CRITICAL: Clamp offset to valid range to prevent flickering at edges
                // Elastic scrolling can cause offset to go beyond maximum, creating feedback loops
                if let documentView = scrollView.documentView {
                    let contentWidth = documentView.frame.width
                    let visibleWidth = scrollView.contentView.bounds.width
                    let maxOffset = max(0, contentWidth - visibleWidth)
                    // Clamp to prevent elastic scrolling from causing oscillation
                    newOffset = min(max(newOffset, 0), maxOffset)
                }
                
                // CRITICAL: Prevent views at position 0 from resetting state.offset
                // This happens when views are recreated during vertical scrolling and start at 0
                // Only update state if:
                // 1. The change is significant (> 0.5 for better performance - less frequent updates)
                // 2. AND we're not resetting from a non-zero state to near-zero UNLESS it's a legitimate scroll
                let isSignificantChange = abs(currentStateOffset - newOffset) > 0.5
                
                // Block updates that would reset state from a significant offset to near-zero
                // This prevents recreated views at position 0 from resetting all views
                // BUT allow legitimate scrolling to position 0 (when scrolling left)
                // Key: If we're scrolling left (newOffset < currentStateOffset), it's legitimate
                let wouldResetToZero = currentStateOffset > 10 && newOffset < 1
                let isScrollingLeft = newOffset < currentStateOffset
                let isLegitimateScrollToZero = isScrollingLeft && newOffset < 1
                
                // Allow update if:
                // - Significant change AND
                //   - Not a reset to zero (wouldResetToZero is false), OR
                //   - It's a legitimate scroll to zero (user scrolling left to position 0)
                if isSignificantChange && (!wouldResetToZero || isLegitimateScrollToZero) {
                    // Only update if the state actually needs to change
                    // This prevents feedback loops where updating state triggers sink which updates views
                    // which trigger notifications which try to update state again
                    // Use currentStateOffset (captured earlier) to avoid race conditions
                    if abs(currentStateOffset - newOffset) > 0.1 {
                        // Update state synchronously (we're already on main thread)
                        // The isUpdatingProgrammatically check at the top prevents re-entry during programmatic updates
                        state.offset = newOffset
                    }
                }
            }
        }

        func updateScrollPositionIfNeeded(scrollView: NSScrollView, targetOffset: CGFloat) {
            let currentOffset = scrollView.contentView.bounds.origin.x
            // Use a very small threshold to avoid unnecessary updates, but ensure accuracy
            if abs(currentOffset - targetOffset) > 0.1 {
                updateScrollPositionImmediately(scrollView: scrollView, targetOffset: targetOffset)
            }
        }
        
        func updateScrollPositionImmediately(scrollView: NSScrollView, targetOffset: CGFloat) {
            let currentOffset = scrollView.contentView.bounds.origin.x
            
            // Clamp target offset to valid range to prevent flickering at edges
            var clampedTarget = targetOffset
            if let documentView = scrollView.documentView {
                let contentWidth = documentView.frame.width
                let visibleWidth = scrollView.contentView.bounds.width
                let maxOffset = max(0, contentWidth - visibleWidth)
                clampedTarget = min(max(targetOffset, 0), maxOffset)
            }
            
            // CRITICAL: Use minimal threshold (0.01) to ensure tight synchronization
            // This ensures all rows stay perfectly aligned during horizontal scrolling
            // Always update if there's any meaningful difference, especially when scrolling to 0
            // Special case: When target is 0, be more aggressive to ensure all views reach 0
            let threshold = clampedTarget == 0 ? 0.1 : 0.01
            if abs(currentOffset - clampedTarget) > threshold {
                state.isUpdatingProgrammatically = true
                scrollView.contentView.scroll(to: NSPoint(x: clampedTarget, y: 0))
                scrollView.reflectScrolledClipView(scrollView.contentView)
                // Keep flag set briefly to prevent notification feedback loop
                // The notification observer checks this flag and will skip updates
                // Reset after a tiny delay to allow scroll to complete without triggering feedback
                DispatchQueue.main.async { [weak self] in
                    guard let self, !self.isDeallocating else { return }
                    state.isUpdatingProgrammatically = false
                }
            }
        }

        deinit {
            isDeallocating = true
            if let observation {
                NotificationCenter.default.removeObserver(observation)
            }
        }
    }
}
#else
import UIKit

private struct Representable<Content: View>: UIViewRepresentable {
    @ObservedObject var state: HorizontalScrollState
    let showsIndicators: Bool
    let contentBuilder: () -> Content

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsHorizontalScrollIndicator = showsIndicators
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceHorizontal = true
        scrollView.alwaysBounceVertical = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.delegate = context.coordinator

        let hostingController = context.coordinator.hostingController
        hostingController.rootView = AnyView(contentBuilder())
        hostingController.view.backgroundColor = .clear

        let hostingView = hostingController.view
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(hostingView)

        context.coordinator.installConstraints(on: hostingView, in: scrollView)
        context.coordinator.scrollView = scrollView
        context.coordinator.updateScrollPositionIfNeeded(scrollView: scrollView, targetOffset: state.offset)

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = AnyView(contentBuilder())
        context.coordinator.scrollView = uiView
        context.coordinator.updateScrollPositionIfNeeded(scrollView: uiView, targetOffset: state.offset)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let state: HorizontalScrollState
        let hostingController: UIHostingController<AnyView>
        fileprivate weak var scrollView: UIScrollView?
        private var cancellable: AnyCancellable?

        init(state: HorizontalScrollState) {
            self.state = state
            self.hostingController = UIHostingController(rootView: AnyView(EmptyView()))
            super.init()

            cancellable = state.$offset.sink { [weak self] newOffset in
                guard let self, let scrollView = self.scrollView else { return }
                DispatchQueue.main.async {
                    self.updateScrollPositionIfNeeded(scrollView: scrollView, targetOffset: newOffset)
                }
            }
        }

        func installConstraints(on hostingView: UIView, in scrollView: UIScrollView) {
            let contentGuide = scrollView.contentLayoutGuide
            let frameGuide = scrollView.frameLayoutGuide

            hostingView.leadingAnchor.constraint(equalTo: contentGuide.leadingAnchor).isActive = true
            hostingView.trailingAnchor.constraint(equalTo: contentGuide.trailingAnchor).isActive = true
            hostingView.topAnchor.constraint(equalTo: contentGuide.topAnchor).isActive = true
            hostingView.bottomAnchor.constraint(equalTo: contentGuide.bottomAnchor).isActive = true
            hostingView.heightAnchor.constraint(equalTo: frameGuide.heightAnchor).isActive = true
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if state.isUpdatingProgrammatically { return }
            let newOffset = scrollView.contentOffset.x
            if abs(state.offset - newOffset) > 0.5 {
                state.offset = newOffset
            }
        }

        func updateScrollPositionIfNeeded(scrollView: UIScrollView, targetOffset: CGFloat) {
            let currentOffset = scrollView.contentOffset.x
            if abs(currentOffset - targetOffset) > 0.5 {
                state.isUpdatingProgrammatically = true
                scrollView.setContentOffset(CGPoint(x: targetOffset, y: 0), animated: false)
                state.isUpdatingProgrammatically = false
            }
        }
    }
}
#endif
