import SwiftUI

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
        #if os(macOS)
        Representable(state: state, showsIndicators: showsIndicators, contentBuilder: contentBuilder)
        #else
        Representable(state: state, showsIndicators: showsIndicators, contentBuilder: contentBuilder)
        #endif
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

        let hostingView = context.coordinator.hostingView
        hostingView.rootView = AnyView(contentBuilder())

        scrollView.documentView = hostingView

        context.coordinator.installConstraints(on: hostingView, in: scrollView)
        context.coordinator.startObserving(scrollView: scrollView)

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.hostingView.rootView = AnyView(contentBuilder())

        let currentOffset = nsView.contentView.bounds.origin.x
        if abs(currentOffset - state.offset) > 0.5 {
            context.coordinator.state.isUpdatingProgrammatically = true
            nsView.contentView.scroll(to: NSPoint(x: state.offset, y: 0))
            nsView.reflectScrolledClipView(nsView.contentView)
            context.coordinator.state.isUpdatingProgrammatically = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    final class Coordinator: NSObject {
        let state: HorizontalScrollState
        let hostingView: NSHostingView<AnyView>
        private var observation: NSKeyValueObservation?

        init(state: HorizontalScrollState) {
            self.state = state
            self.hostingView = NSHostingView(rootView: AnyView(EmptyView()))
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
            observation?.invalidate()
            observation = scrollView.contentView.observe(\.bounds, options: [.new]) { [weak self] clipView, _ in
                guard let self else { return }
                if state.isUpdatingProgrammatically { return }
                let newOffset = clipView.bounds.origin.x
                if abs(state.offset - newOffset) > 0.5 {
                    DispatchQueue.main.async {
                        self.state.offset = newOffset
                    }
                }
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

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = AnyView(contentBuilder())

        let currentOffset = uiView.contentOffset.x
        if abs(currentOffset - state.offset) > 0.5 {
            context.coordinator.state.isUpdatingProgrammatically = true
            uiView.setContentOffset(CGPoint(x: state.offset, y: 0), animated: false)
            context.coordinator.state.isUpdatingProgrammatically = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        let state: HorizontalScrollState
        let hostingController: UIHostingController<AnyView>

        init(state: HorizontalScrollState) {
            self.state = state
            self.hostingController = UIHostingController(rootView: AnyView(EmptyView()))
            super.init()
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
    }
}
#endif
