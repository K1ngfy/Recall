import SwiftUI
import AppKit

/// First-launch onboarding: single-page Apple HIG style.
/// Layout (top to bottom):
/// 1. Hero icon + title + subtitle.
/// 2. 3 feature rows (icon + title + hint).
/// 3. Permission card (shown when not authorized, guides user to Settings).
/// 4. Primary CTA "Get Started" + secondary CTA "Maybe later".
/// - Uses @AppStorage(UserDefaultsKeys.Onboarding.completed) to mark completion.
/// - OnboardingController closes this window when already completed.
struct OnboardingView: View {
    @AppStorage(UserDefaultsKeys.Onboarding.completed) private var completed: Bool = false
    @State private var permissions = PermissionCenter.shared
    @State private var showPermissionHint = false

    var body: some View {
        if !completed {
            VStack(spacing: 0) {
                Spacer().frame(height: 24)

                heroIcon
                    .padding(.bottom, 16)

                VStack(spacing: 6) {
                    Text(Strings.Onboarding.welcomeTitle)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(Strings.Onboarding.welcomeSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 40)

                featureList
                    .padding(.top, 22)
                    .padding(.horizontal, 40)

                permissionCard
                    .padding(.top, 18)
                    .padding(.horizontal, 40)

                Spacer()

                bottomBar
                    .padding(.horizontal, 40)
                    .padding(.bottom, 22)
            }
            .frame(width: 560, height: 540)
            .background(GlassPanelBackground(cornerRadius: 18))
            .overlay(alignment: .bottom) {
                if showPermissionHint && !permissions.axiOSTrusted {
                    Text(Strings.HotkeyConflict.subtitle(Strings.Panel.manageSnippets))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)
                }
            }
        }
    }

    // MARK: - Hero

    private var heroIcon: some View {
        ZStack {
            // Outer soft halo.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.0)],
                        center: .center,
                        startRadius: 24,
                        endRadius: 64
                    )
                )
                .frame(width: 120, height: 120)
            // Inner circle + accent.
            Circle()
                .fill(Color.accentColor.opacity(0.14))
                .frame(width: 76, height: 76)
            Image(systemName: "doc.on.clipboard.fill")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(Color.accentColor)
        }
    }

    // MARK: - Feature list

    private struct FeatureItem: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let hint: String
    }

    private var features: [FeatureItem] {
        [
            FeatureItem(icon: "bolt.fill",          title: "Fast",    hint: "Opens in 220ms via ⌥⌘V"),
            FeatureItem(icon: "eye.slash.fill",     title: "Private", hint: "All data stays on your Mac"),
            FeatureItem(icon: "sparkles",           title: "Smart",   hint: "Auto-paste into any text field"),
        ]
    }

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(features) { item in
                HStack(spacing: 12) {
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle().fill(Color.accentColor.opacity(0.12))
                        )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(item.hint)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Permission card

    @ViewBuilder
    private var permissionCard: some View {
        if !permissions.axiOSTrusted {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 1) {
                    Text(Strings.Onboarding.autopasteTitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(Strings.Onboarding.autopasteBody)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button(Strings.Onboarding.openSettings) {
                    permissions.requestAXWithPrompt()
                    showPermissionHint = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.orange.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
            )
        }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(Strings.MenuBar.welcome) {
                completed = true
                DispatchQueue.main.async {
                    OnboardingController.shared.close()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .font(.system(size: 12))

            Spacer()

            Button(Strings.Onboarding.continue_) {
                // Complete + auto-attempt to pull up the permission prompt (if user hasn't authorized yet).
                completed = true
                if !permissions.axiOSTrusted {
                    permissions.requestAXWithPrompt()
                }
                DispatchQueue.main.async {
                    OnboardingController.shared.close()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.defaultAction)
        }
    }
}
