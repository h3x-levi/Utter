import SwiftUI
import AppKit

/// Native macOS Liquid Glass Login & Welcome Experience.
///
/// Fully aligned with Utter's design system tokens, Bento architecture,
/// and Onboarding flow geometry (700×540, OnboardingBacking, BentoTile, GlassButton).
@MainActor
final class LoginViewModel: ObservableObject {
    @Published var isGoogleLoading = false
    @Published var isAppleLoading = false
    @Published var isHoveringGoogle = false
    @Published var isHoveringApple = false
    @Published var isHoveringGuest = false

    func signInGoogle(userData: UserData, onComplete: @escaping (_ isGuest: Bool) -> Void) {
        isGoogleLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            userData.signInWithGoogle(name: "Alex Rivers", email: "alex.rivers@gmail.com")
            self?.isGoogleLoading = false
            onComplete(false)
        }
    }

    func signInApple(userData: UserData, onComplete: @escaping (_ isGuest: Bool) -> Void) {
        isAppleLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            userData.signInWithGoogle(name: "Apple User", email: "user@privaterelay.appleid.com")
            userData.authProvider = "Apple"
            userData.save()
            self?.isAppleLoading = false
            onComplete(false)
        }
    }

    func skip(userData: UserData, onComplete: @escaping (_ isGuest: Bool) -> Void) {
        userData.signInAsGuest()
        onComplete(true)
    }
}

public struct LoginView: View {
    public var onComplete: (_ isGuest: Bool) -> Void

    @ObservedObject private var userData = UserData.shared
    @ObservedObject private var motion = MotionPreference.shared
    @StateObject private var model = LoginViewModel()

    public init(onComplete: @escaping (_ isGuest: Bool) -> Void) {
        self.onComplete = onComplete
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Top Header Bar (matches Onboarding step dots)
            HStack {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(Tint.accent)
                        .frame(width: 18, height: 6)
                    ForEach(0..<6) { _ in
                        Circle()
                            .fill(Color.primary.opacity(0.12))
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                // Account status chip
                HStack(spacing: 4) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 11))
                        .foregroundStyle(Tint.accent)
                    Text("Account")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(Ink.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .clipShape(Capsule())
            }
            .padding(.horizontal, Space.x5)
            .padding(.top, 18)

            // Centered Scrollable Step Content
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 0)
                        welcomeContent
                        Spacer(minLength: 0)
                    }
                    .frame(minWidth: proxy.size.width, minHeight: proxy.size.height)
                }
            }

            // Bottom Navigation Bar
            HStack {
                GlassButton(title: "Skip") {
                    model.skip(userData: userData, onComplete: onComplete)
                }

                Spacer()

                GlassButton(title: "Continue", prominent: true) {
                    if userData.isAuthenticated {
                        onComplete(false)
                    } else {
                        model.skip(userData: userData, onComplete: onComplete)
                    }
                }
            }
            .padding(Space.x5)
        }
        .frame(minWidth: Layout.onboardingMinWidth,
               idealWidth: Layout.onboardingIdealWidth,
               maxWidth: .infinity,
               minHeight: Layout.onboardingMinHeight,
               idealHeight: Layout.onboardingIdealHeight,
               maxHeight: .infinity)
        .background(OnboardingBacking())
    }

    // MARK: - Welcome Content

    @ViewBuilder
    private var welcomeContent: some View {
        VStack(spacing: Space.x4) {
            // Hero App Icon & Title
            VStack(spacing: Space.x3) {
                AppIconView(size: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)

                VStack(spacing: 4) {
                    Text("Welcome to Utter")
                        .typo(.title)
                    Text("Private on-device dictation & AI workflow companion for macOS")
                        .typo(.caption, ink: Ink.secondary)
                }
            }

            // Authentication Mode Selector Card
            BentoTile(title: "Account & Cloud Sync", systemImage: "person.crop.circle.badge.checkmark", tint: Tint.accent) {
                VStack(alignment: .leading, spacing: Space.x3) {
                    Text("Signing in enables seamless history backups, personal dictionary sync, and multi-device preference storage.")
                        .typo(.callout)
                        .fixedSize(horizontal: false, vertical: true)

                    if userData.isAuthenticated {
                        // Already Authenticated State
                        HStack(spacing: Space.x3) {
                            ZStack {
                                Circle()
                                    .fill(Tint.accent.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Tint.accent)
                                    .font(.system(size: 16))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Signed in as \(userData.userDisplayName)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Ink.primary)
                                Text(userData.userEmail.isEmpty ? "Connected via \(userData.authProvider)" : userData.userEmail)
                                    .font(.caption)
                                    .foregroundStyle(Ink.secondary)
                            }

                            Spacer()

                            Button("Sign Out") {
                                userData.signOut()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        .padding(Space.x2)
                        .background(Color.primary.opacity(0.03))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        // Sign-In Actions
                        HStack(spacing: Space.x3) {
                            // Google Sign In Button
                            Button {
                                model.signInGoogle(userData: userData, onComplete: onComplete)
                            } label: {
                                HStack(spacing: Space.x2) {
                                    if model.isGoogleLoading {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        GoogleVectorLogo(size: 16)
                                    }
                                    Text(model.isGoogleLoading ? "Connecting…" : "Sign in with Google")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(Color(nsColor: .controlBackgroundColor))
                                .foregroundColor(Color.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.primary.opacity(model.isHoveringGoogle ? 0.2 : 0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .onHover { model.isHoveringGoogle = $0 }
                            .disabled(model.isGoogleLoading || model.isAppleLoading)

                            // Apple Sign In Button
                            Button {
                                model.signInApple(userData: userData, onComplete: onComplete)
                            } label: {
                                HStack(spacing: Space.x2) {
                                    if model.isAppleLoading {
                                        ProgressView()
                                            .controlSize(.small)
                                            .frame(width: 16, height: 16)
                                    } else {
                                        Image(systemName: "apple.logo")
                                            .font(.system(size: 14, weight: .semibold))
                                    }
                                    Text(model.isAppleLoading ? "Authenticating…" : "Sign in with Apple")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(Color.primary)
                                .foregroundColor(Color(nsColor: .windowBackgroundColor))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .opacity(model.isHoveringApple ? 0.9 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .onHover { model.isHoveringApple = $0 }
                            .disabled(model.isGoogleLoading || model.isAppleLoading)
                        }

                        // Guest Mode Alternative Row
                        Button {
                            model.skip(userData: userData, onComplete: onComplete)
                        } label: {
                            HStack(spacing: Space.x3) {
                                ZStack {
                                    Circle()
                                        .fill(Color.primary.opacity(0.06))
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "person.badge.shield.checkmark")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Ink.secondary)
                                }

                                VStack(alignment: .leading, spacing: 1) {
                                    Text("Continue Offline as Guest")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(Ink.primary)
                                    Text("No account required. All preferences and audio remain local to this Mac.")
                                        .font(.caption2)
                                        .foregroundStyle(Ink.secondary)
                                }

                                Spacer()

                                Image(systemName: "arrow.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Tint.accent)
                            }
                            .padding(.horizontal, Space.x2)
                            .padding(.vertical, 6)
                            .background(Color.primary.opacity(model.isHoveringGuest ? 0.04 : 0.02))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .onHover { model.isHoveringGuest = $0 }
                    }
                }
            }

            // Privacy Guarantee Bento Card
            BentoTile(title: "Private by design", systemImage: "lock.shield", tint: Tint.accent) {
                HStack(spacing: Space.x3) {
                    Text("Speech recognition and AI features run 100% on Apple Silicon Neural Engines. Utter never transmits audio buffers or keystrokes to the cloud.")
                        .typo(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.x8)
    }
}

// MARK: - Official Vector Google 'G' Logo

struct GoogleVectorLogo: View {
    var size: CGFloat = 16

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let cx = w / 2
            let cy = h / 2
            let outerRadius = w / 2
            let innerRadius = w * 0.28

            let blue = Color(red: 66/255, green: 133/255, blue: 244/255)
            let red = Color(red: 234/255, green: 67/255, blue: 53/255)
            let yellow = Color(red: 251/255, green: 188/255, blue: 5/255)
            let green = Color(red: 52/255, green: 168/255, blue: 83/255)

            // Blue Sector
            var blueSector = Path()
            blueSector.addArc(center: CGPoint(x: cx, y: cy), radius: outerRadius, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
            blueSector.addLine(to: CGPoint(x: cx, y: cy))
            blueSector.closeSubpath()
            context.fill(blueSector, with: .color(blue))

            // Green Sector
            var greenSector = Path()
            greenSector.addArc(center: CGPoint(x: cx, y: cy), radius: outerRadius, startAngle: .degrees(45), endAngle: .degrees(135), clockwise: false)
            greenSector.addLine(to: CGPoint(x: cx, y: cy))
            greenSector.closeSubpath()
            context.fill(greenSector, with: .color(green))

            // Yellow Sector
            var yellowSector = Path()
            yellowSector.addArc(center: CGPoint(x: cx, y: cy), radius: outerRadius, startAngle: .degrees(135), endAngle: .degrees(225), clockwise: false)
            yellowSector.addLine(to: CGPoint(x: cx, y: cy))
            yellowSector.closeSubpath()
            context.fill(yellowSector, with: .color(yellow))

            // Red Sector
            var redSector = Path()
            redSector.addArc(center: CGPoint(x: cx, y: cy), radius: outerRadius, startAngle: .degrees(225), endAngle: .degrees(315), clockwise: false)
            redSector.addLine(to: CGPoint(x: cx, y: cy))
            redSector.closeSubpath()
            context.fill(redSector, with: .color(red))

            // Inner Cutout
            let innerRect = CGRect(x: cx - innerRadius, y: cy - innerRadius, width: innerRadius * 2, height: innerRadius * 2)
            context.blendMode = .clear
            context.fill(Path(ellipseIn: innerRect), with: .color(.black))
            context.blendMode = .normal

            // Google Right Horizontal Crossbar
            var crossbar = Path()
            crossbar.addRect(CGRect(x: cx - (w * 0.05), y: cy - (w * 0.11), width: outerRadius * 1.05, height: w * 0.22))
            context.fill(crossbar, with: .color(blue))
        }
        .frame(width: size, height: size)
    }
}

