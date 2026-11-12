import UIKit

private final class TestPan: UIPanGestureRecognizer {
  var phase: UIGestureRecognizer.State = .possible
  var point = CGPoint.zero
  var touches = 1
  override var state: UIGestureRecognizer.State {
    get { phase }
    set { phase = newValue }
  }
  override var numberOfTouches: Int { touches }
  override func translation(in view: UIView?) -> CGPoint { point }
}

private final class ScrollDelegate: NSObject, UIScrollViewDelegate {}

@main
private struct BrowserScrollObservationTest {
  static func flush() {
    RunLoop.main.run(until: Date().addingTimeInterval(0.01))
  }

  static func main() {
    let scroll = UIScrollView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
    scroll.contentSize = CGSize(width: 390, height: 3000)
    scroll.contentInset = UIEdgeInsets(top: 59, left: 0, bottom: 34, right: 0)
    scroll.contentOffset = CGPoint(x: 0, y: -59)
    let delegate = ScrollDelegate()
    scroll.delegate = delegate
    let recognizers = scroll.gestureRecognizers?.count
    let pan = TestPan()
    var events: [[String: Any]] = []
    var observer: BrowserScrollObservation? = BrowserScrollObservation(
      scrollView: scroll, visible: true, pan: pan
    ) { events.append($0) }
    assert(scroll.delegate === delegate)
    assert(scroll.gestureRecognizers?.count == recognizers)
    assert(events.last?["phase"] as? String == "reset")
    assert(events.last?["offset"] as? Double == 0)
    assert(events.last?["viewportExtent"] as? Double == 844)
    assert(events.last?["contentExtent"] as? Double == 3093)

    let initial = events.count
    scroll.contentOffset.y = 10
    scroll.contentOffset.y = 20
    scroll.contentSize.height = 3200
    flush()
    assert(events.count == initial + 1, "Offset, bounds and content-size changes coalesce")
    assert(events.last?["isUserInteracting"] as? Bool == false)

    pan.phase = .began
    pan.point.y = -15
    observer?.panChanged(pan)
    scroll.contentOffset.y = 35
    flush()
    assert(events.last?["isUserInteracting"] as? Bool == true)
    assert(events.last?["gestureDelta"] as? Double == 15)
    pan.phase = .changed
    pan.point.y = -35
    observer?.panChanged(pan)
    pan.phase = .ended
    let release = events.count
    observer?.panChanged(pan)
    assert(events[release]["gestureDelta"] as? Double == 20)
    assert(events[release]["isUserInteracting"] as? Bool == true)
    assert(events.last?["isUserInteracting"] as? Bool == false)
    scroll.contentOffset.y = 500
    flush()
    assert(events.last?["gestureDelta"] as? Double == 0)
    assert(events.last?["isUserInteracting"] as? Bool == false)

    // Cancellation cannot permanently disarm the next native pan.
    pan.phase = .began
    pan.point.y = -20
    observer?.panChanged(pan)
    pan.phase = .cancelled
    observer?.panChanged(pan)
    flush()
    assert(events.last?["isUserInteracting"] as? Bool == false)
    assert(events.last?["gestureDelta"] as? Double == 0)
    pan.phase = .began
    pan.point.y = 12
    observer?.panChanged(pan)
    flush()
    assert(events.last?["isUserInteracting"] as? Bool == true)
    assert(events.last?["gestureDelta"] as? Double == -12)

    pan.phase = .changed
    pan.touches = 2
    pan.point.y = 24
    observer?.panChanged(pan)
    flush()
    assert(events.last?["isUserInteracting"] as? Bool == false)
    observer?.setVisible(false)
    let covered = events.count
    scroll.contentOffset.y = 600
    flush()
    assert(events.count == covered, "Covered views send no scroll messages")
    observer?.setVisible(true)
    assert(events.last?["phase"] as? String == "reset")

    // A disposed lease cancels pending work and removes all KVO/target work.
    scroll.contentOffset.y = 700
    observer?.dispose()
    let disposed = events.count
    flush()
    scroll.contentOffset.y = 800
    observer?.panChanged(pan)
    flush()
    assert(events.count == disposed)
    assert(scroll.delegate === delegate)
    weak let released = observer
    observer = nil
    assert(released == nil)
    print("Browser native scroll: KVO coalescing, pan/release/cancel, insets, visibility, delegate preservation and disposal passed")
  }
}
