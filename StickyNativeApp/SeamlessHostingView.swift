import AppKit
import SwiftUI

final class SeamlessHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  // Suppress the title bar safe area inset that .titled + .fullSizeContentView windows inject.
  // Without this, SwiftUI offsets content by ~28px, misaligning the visual chrome with the
  // window frame edges (drag target and resize handles appear in empty transparent space).
  override var safeAreaInsets: NSEdgeInsets {
    .init()
  }
}
