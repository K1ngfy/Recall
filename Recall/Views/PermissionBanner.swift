import SwiftUI

/// Permission guidance banner. Renders different prompts based on PermissionCenter state.
struct PermissionBanner: View {
    @Bindable var permissions: PermissionCenter
    @State private var dismissed = false

    var body: some View {
        if let kind = bannerKind, !dismissed {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: kind.symbolName)  // Defined inside BannerKind.symbolName
                    .foregroundStyle(kind.tint)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(kind.message)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Button(kind.actionTitle) {
                    kind.action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(kind.tint)

                // Close button (only for the AX banner; secureInput is a transient state and should not be dismissible)
                if kind == .axMissing {
                    Button {
                        dismissed = true
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Dismiss for this session")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(kind.tint.opacity(0.10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(kind.tint.opacity(0.30), lineWidth: 0.5)
                    )
            )
            .padding(.horizontal, 10)
            .padding(.top, 6)
        }
    }

    // MARK: - Banner kinds

    private enum BannerKind: Equatable {
        case axMissing
        case secureInput

        var symbolName: String {
            switch self {
            case .axMissing:    return "lock.shield"
            case .secureInput:  return "exclamationmark.shield"
            }
        }

        var title: String {
            switch self {
            case .axMissing:   return "Auto-paste needs Accessibility"
            case .secureInput: return "Secure Input is active"
            }
        }

        var message: String {
            switch self {
            case .axMissing:
                return "Grant Recall access in System Settings → Privacy & Security → Accessibility to enable auto-paste."
            case .secureInput:
                return "Current app blocks synthetic input. Item copied — paste manually with ⌘V."
            }
        }

        var actionTitle: String {
            switch self {
            case .axMissing:   return "Open Settings"
            case .secureInput: return "OK"
            }
        }

        var tint: Color {
            switch self {
            case .axMissing:   return .orange
            case .secureInput: return .yellow
            }
        }

        @MainActor
        func action() {
            switch self {
            case .axMissing:
                PermissionCenter.openAccessibilitySettings()
            case .secureInput:
                break
            }
        }
    }

    private var bannerKind: BannerKind? {
        if !permissions.axiOSTrusted {
            return .axMissing
        } else if permissions.isSecureInputActive {
            return .secureInput
        }
        return nil
    }
}
