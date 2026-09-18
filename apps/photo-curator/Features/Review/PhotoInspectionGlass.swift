import SwiftUI

struct InspectionGlassLabelStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
                .glassEffect(.regular.tint(.white.opacity(0.10)), in: .rect(cornerRadius: 16))
        } else {
            content
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
        }
    }
}

struct InspectionGlassGroupModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 8) {
                content.padding(6)
            }
        } else {
            content
                .padding(6)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.14), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.28), radius: 16, y: 8)
        }
    }
}

extension View {
    func inspectionGlassGroup() -> some View {
        modifier(InspectionGlassGroupModifier())
    }
}

struct InspectionButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case navigation

        var background: Color {
            switch self {
            case .primary:
                Color.curatorAccent
            case .secondary:
                .white.opacity(0.14)
            case .navigation:
                .white.opacity(0.10)
            }
        }

        var foreground: Color {
            .white
        }

        var stroke: Color {
            switch self {
            case .primary:
                .white.opacity(0.22)
            case .secondary, .navigation:
                .white.opacity(0.12)
            }
        }

        var glassBacking: Color {
            switch self {
            case .primary:
                Color.curatorAccent.opacity(0.10)
            case .secondary, .navigation:
                .white.opacity(0.06)
            }
        }

        @available(iOS 26, *)
        var glass: Glass {
            switch self {
            case .primary:
                .regular.tint(Color.curatorAccent.opacity(0.72)).interactive()
            case .secondary, .navigation:
                .regular.tint(.white.opacity(0.10)).interactive()
            }
        }
    }

    let kind: Kind
    let reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(kind.foreground)
            .padding(.horizontal, 14)
            .frame(minHeight: 44)

        Group {
            if #available(iOS 26, *) {
                label
                    .background(kind.glassBacking, in: .rect(cornerRadius: 16))
                    .glassEffect(kind.glass, in: .rect(cornerRadius: 16))
            } else {
                label
                    .background(
                        kind.background,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(kind.stroke, lineWidth: 1)
                    }
            }
        }
        .scaleEffect(configuration.isPressed ? 0.96 : 1)
        .opacity(configuration.isPressed ? 0.84 : 1)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}
