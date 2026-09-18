import SwiftUI
import UIKit

/// Transparent UIKit view coordinator that attaches swipe-to-select and long-press
/// drag selection with CADisplayLink auto-scrolling to the enclosing UIScrollView.
struct PhotoGridDragSelector: UIViewRepresentable {
    let itemCount: Int
    let columnsCount: Int
    let spacing: CGFloat
    let onDragStart: (Int) -> (isSelecting: Bool, initialSelection: Set<AssetID>)
    let onDragUpdate: (Int, Int, Bool, Set<AssetID>) -> Void
    let onDragEnd: () -> Void

    func makeUIView(context: Context) -> DragSelectorHostView {
        let view = DragSelectorHostView()
        view.coordinator = context.coordinator
        return view
    }

    func updateUIView(_ uiView: DragSelectorHostView, context: Context) {
        uiView.coordinator = context.coordinator
        context.coordinator.itemCount = itemCount
        context.coordinator.columnsCount = columnsCount
        context.coordinator.spacing = spacing
        context.coordinator.onDragStart = onDragStart
        context.coordinator.onDragUpdate = onDragUpdate
        context.coordinator.onDragEnd = onDragEnd
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            itemCount: itemCount,
            columnsCount: columnsCount,
            spacing: spacing,
            onDragStart: onDragStart,
            onDragUpdate: onDragUpdate,
            onDragEnd: onDragEnd
        )
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var itemCount: Int
        var columnsCount: Int
        var spacing: CGFloat
        var onDragStart: (Int) -> (isSelecting: Bool, initialSelection: Set<AssetID>)
        var onDragUpdate: (Int, Int, Bool, Set<AssetID>) -> Void
        var onDragEnd: () -> Void

        private weak var hostView: UIView?
        private weak var scrollView: UIScrollView?
        private var panGesture: UIPanGestureRecognizer?
        private var longPressGesture: UILongPressGestureRecognizer?
        private var displayLink: CADisplayLink?
        private let feedbackGenerator = UISelectionFeedbackGenerator()

        private var isDragging = false
        private var isSelecting = true
        private var startIndex = 0
        private var lastReportedIndex = -1
        private var initialSelection = Set<AssetID>()
        private weak var activeGesture: UIGestureRecognizer?

        init(
            itemCount: Int,
            columnsCount: Int,
            spacing: CGFloat,
            onDragStart: @escaping (Int) -> (isSelecting: Bool, initialSelection: Set<AssetID>),
            onDragUpdate: @escaping (Int, Int, Bool, Set<AssetID>) -> Void,
            onDragEnd: @escaping () -> Void
        ) {
            self.itemCount = itemCount
            self.columnsCount = columnsCount
            self.spacing = spacing
            self.onDragStart = onDragStart
            self.onDragUpdate = onDragUpdate
            self.onDragEnd = onDragEnd
            super.init()
        }

        deinit {
            displayLink?.invalidate()
            if let pan = panGesture {
                pan.view?.removeGestureRecognizer(pan)
            }
            if let lp = longPressGesture {
                lp.view?.removeGestureRecognizer(lp)
            }
        }

        func attachIfNeeded(hostView: UIView) {
            self.hostView = hostView
            guard let sv = hostView.enclosingScrollView else { return }
            if scrollView === sv {
                return
            }
            scrollView = sv

            if let pan = panGesture {
                pan.view?.removeGestureRecognizer(pan)
            }
            if let lp = longPressGesture {
                lp.view?.removeGestureRecognizer(lp)
            }

            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            pan.delegate = self
            sv.addGestureRecognizer(pan)
            panGesture = pan

            let lp = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
            lp.minimumPressDuration = 0.25
            lp.delegate = self
            sv.addGestureRecognizer(lp)
            longPressGesture = lp
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            if gestureRecognizer === panGesture {
                guard let sv = scrollView else { return false }
                let velocity = panGesture?.velocity(in: sv) ?? .zero
                // Horizontal swipe: begins swipe-to-select immediately
                if abs(velocity.x) > abs(velocity.y) * 1.0 && abs(velocity.x) > 30 {
                    return true
                }
                return false
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            !isDragging
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            handleGesture(gesture)
        }

        @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            handleGesture(gesture)
        }

        private func handleGesture(_ gesture: UIGestureRecognizer) {
            switch gesture.state {
            case .began:
                guard !isDragging else { return }
                beginDrag(with: gesture)
            case .changed:
                guard isDragging, activeGesture === gesture else { return }
                updateDrag()
            case .ended, .cancelled, .failed:
                if activeGesture === gesture {
                    endDrag()
                }
            default:
                break
            }
        }

        private func beginDrag(with gesture: UIGestureRecognizer) {
            guard let host = hostView, let sv = scrollView, itemCount > 0 else { return }
            isDragging = true
            activeGesture = gesture

            // Temporarily disable and re-enable scroll pan to cancel standard scroll
            sv.panGestureRecognizer.isEnabled = false
            sv.panGestureRecognizer.isEnabled = true

            let pointInGrid = gesture.location(in: host)
            startIndex = calculateIndex(at: pointInGrid)
            lastReportedIndex = startIndex

            let startResult = onDragStart(startIndex)
            isSelecting = startResult.isSelecting
            initialSelection = startResult.initialSelection

            feedbackGenerator.prepare()
            feedbackGenerator.selectionChanged()

            onDragUpdate(startIndex, startIndex, isSelecting, initialSelection)
            startAutoScroll()
        }

        private func updateDrag() {
            guard let host = hostView, let gesture = activeGesture, itemCount > 0 else { return }
            let pointInGrid = gesture.location(in: host)
            let currentIndex = calculateIndex(at: pointInGrid)
            if currentIndex != lastReportedIndex {
                lastReportedIndex = currentIndex
                feedbackGenerator.selectionChanged()
                onDragUpdate(startIndex, currentIndex, isSelecting, initialSelection)
            }
        }

        private func endDrag() {
            isDragging = false
            activeGesture = nil
            stopAutoScroll()
            onDragEnd()
        }

        private func startAutoScroll() {
            stopAutoScroll()
            let link = CADisplayLink(target: self, selector: #selector(autoScrollTick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        }

        private func stopAutoScroll() {
            displayLink?.invalidate()
            displayLink = nil
        }

        @objc private func autoScrollTick(_ link: CADisplayLink) {
            guard isDragging, let gesture = activeGesture, let sv = scrollView else {
                stopAutoScroll()
                return
            }

            let pointInSV = gesture.location(in: sv)
            let visibleRect = CGRect(origin: sv.contentOffset, size: sv.bounds.size)
            let edgeInset: CGFloat = 70

            let distFromTop = pointInSV.y - visibleRect.minY
            let distFromBottom = visibleRect.maxY - pointInSV.y
            var scrollDelta: CGFloat = 0

            if distFromTop < edgeInset, distFromTop >= -20 {
                let factor = max(0, min(1, (edgeInset - distFromTop) / edgeInset))
                scrollDelta = -700 * factor * CGFloat(link.duration)
            } else if distFromBottom < edgeInset, distFromBottom >= -20 {
                let factor = max(0, min(1, (edgeInset - distFromBottom) / edgeInset))
                scrollDelta = 700 * factor * CGFloat(link.duration)
            }

            if scrollDelta != 0 {
                let minOffset = -sv.adjustedContentInset.top
                let maxOffset = max(
                    minOffset,
                    sv.contentSize.height - sv.bounds.height + sv.adjustedContentInset.bottom
                )
                let newOffset = max(minOffset, min(maxOffset, sv.contentOffset.y + scrollDelta))

                if newOffset != sv.contentOffset.y {
                    sv.contentOffset.y = newOffset
                    updateDrag()
                }
            }
        }

        private func calculateIndex(at point: CGPoint) -> Int {
            guard let host = hostView, itemCount > 0 else { return 0 }
            let totalWidth = host.bounds.width
            guard totalWidth > 0 else { return 0 }

            let colSpacing = spacing
            let rowSpacing = spacing
            let numCols = CGFloat(columnsCount)
            let itemWidth = (totalWidth - colSpacing * (numCols - 1)) / numCols
            let itemHeight = itemWidth

            let totalColWidth = itemWidth + colSpacing
            let totalRowHeight = itemHeight + rowSpacing

            let col = min(max(Int(point.x / totalColWidth), 0), columnsCount - 1)
            let row = max(Int(point.y / totalRowHeight), 0)
            let index = row * columnsCount + col

            return min(max(index, 0), itemCount - 1)
        }
    }
}

final class DragSelectorHostView: UIView {
    weak var coordinator: PhotoGridDragSelector.Coordinator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            coordinator?.attachIfNeeded(hostView: self)
        }
    }
}

private extension UIView {
    var enclosingScrollView: UIScrollView? {
        var current: UIView? = superview
        while let view = current {
            if let sv = view as? UIScrollView {
                return sv
            }
            current = view.superview
        }
        return nil
    }
}
