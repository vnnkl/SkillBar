import SwiftUI

struct GlassButtonStyle: ButtonStyle {

    func makeBody(configuration: Configuration) -> some View {
        GlassButtonBody(configuration: configuration)
    }
}

private struct GlassButtonBody: View {
    let configuration: ButtonStyleConfiguration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .frame(
                minWidth: Constants.buttonMinSize,
                minHeight: Constants.buttonMinSize
            )
            .background(
                Circle()
                    .fill(isHovered ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.clear))
            )
            .overlay(
                Circle()
                    .strokeBorder(
                        Color.primary.opacity(isHovered ? 0.1 : 0),
                        lineWidth: 0.5
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.88 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}
