import SwiftUI

/// Background capsule for the accent selected state. `Color.accentColor.opacity(0.18)` + any rounded shape.
/// Usage:
///   `.background(AccentCapsule(shape: Capsule()))`
///   `.background(AccentCapsule(shape: RoundedRectangle(cornerRadius: 6)))`
struct AccentCapsule<S: Shape>: View {
    let shape: S
    var opacity: CGFloat = 0.18

    var body: some View {
        shape.fill(Color.accentColor.opacity(opacity))
    }
}
