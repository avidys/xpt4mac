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
        self.state = state
        self.showsIndicators = showsIndicators
        self.contentBuilder = content
    }

    var body: some View {
        #if os(macOS)
        Representable(state: state, showsIndicators: showsIndicators, contentBuilder: contentBuilder)
        #else
        ScrollView(.horizontal, showsIndicators: showsIndicators) {
            contentBuilder()
        }
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

            guard let contentView = scrollView.contentView as? NSView else { return }

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
#endif
