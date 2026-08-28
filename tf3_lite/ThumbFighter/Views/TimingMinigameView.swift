import SwiftUI

struct PowerClashView: View {
    let powerClash: PowerClash
    let holdState: HoldState
    let pendingPowerUp: PowerUpType?
    let activePowerUp: ActivePowerUp?
    let powerUpFlash: PowerUpType?
    let onTap: () -> Void
    let onCollectPowerUp: () -> Void

    @State private var tapPulse: Bool = false
    @State private var barGlowOpacity: Double = 0

    private var markerFraction: CGFloat {
        CGFloat((powerClash.progress + 1) / 2)
    }

    private var statusText: String {
        switch holdState {
        case .playerHolding: return "BOT IS PINNED! 👇"
        case .botHolding:    return "YOU'RE PINNED! FIGHT BACK!"
        case .none:          return "POWER STRUGGLE"
        }
    }

    private var statusColor: Color {
        switch holdState {
        case .playerHolding: return Color(hex: "4cff72")
        case .botHolding:    return Color(hex: "ff6b6b")
        case .none:          return .white
        }
    }

    // Bar glow color matches the active power-up
    private var barGlowColor: Color {
        activePowerUp?.type.color ?? .white
    }

    var body: some View {
        ZStack {
            RapidTapView { onTap() }
                .ignoresSafeArea()

            VStack {
                // Active power-up banner
                if let active = activePowerUp {
                    activePowerUpBanner(active)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 60)
                }

                Spacer()

                // Pending power-up button — separate from the mash area
                if let pending = pendingPowerUp {
                    pendingPowerUpButton(pending)
                        .transition(.scale.combined(with: .opacity))
                        .padding(.bottom, 12)
                }

                // TAP instruction banner
                VStack(spacing: 4) {
                    Text("TAP! TAP! TAP!")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: Color(hex: "00e5ff").opacity(0.9), radius: 10)
                        .scaleEffect(tapPulse ? 1.12 : 0.95)
                        .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true), value: tapPulse)
                        .onAppear { tapPulse = true }
                }
                .padding(.bottom, 8)

                VStack(spacing: 10) {
                    Text(statusText)
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundColor(statusColor)
                        .shadow(color: .black.opacity(0.6), radius: 4)
                        .animation(.easeInOut(duration: 0.2), value: holdState == .none)

                    GeometryReader { geo in
                        let barW = geo.size.width
                        let markerW: CGFloat = 20
                        let markerX = markerFraction * barW - markerW / 2

                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.4))
                                .frame(height: 36)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                                )

                            // Power-up flash glow overlay on the whole bar
                            RoundedRectangle(cornerRadius: 20)
                                .fill(barGlowColor.opacity(barGlowOpacity))
                                .frame(height: 36)
                                .allowsHitTesting(false)

                            // Player fill
                            RoundedRectangle(cornerRadius: 20)
                                .fill(LinearGradient(
                                    colors: activePowerUp?.type == .speedBurst
                                        ? [Color(hex: "ffe600"), Color(hex: "ff9900")]
                                        : [Color(hex: "00e5ff"), Color(hex: "4cff72")],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                                .frame(width: max(0, markerX + markerW / 2), height: 22)
                                .padding(.horizontal, 7)

                            // Bot fill
                            HStack(spacing: 0) {
                                Spacer(minLength: max(0, markerX + markerW / 2 + 14))
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(LinearGradient(
                                        colors: activePowerUp?.type == .freeze
                                            ? [Color(hex: "00e5ff").opacity(0.4), Color(hex: "aaeeff").opacity(0.4)]
                                            : [Color(hex: "ff9900"), Color(hex: "e94560")],
                                        startPoint: .leading, endPoint: .trailing
                                    ))
                                    .frame(height: 22)
                                    .padding(.trailing, 7)
                            }

                            // Centre line
                            Rectangle()
                                .fill(Color.white.opacity(0.4))
                                .frame(width: 2, height: 44)
                                .offset(x: barW / 2 - 1)

                            pinZoneMarker(at: 0.35 * barW, barH: 36)
                            pinZoneMarker(at: 0.65 * barW, barH: 36)

                            // Shield zone highlight
                            if activePowerUp?.type == .shield {
                                RoundedRectangle(cornerRadius: 20)
                                    .strokeBorder(Color(hex: "4cff72").opacity(0.8), lineWidth: 3)
                                    .frame(width: barW / 2, height: 36)
                                    .offset(x: 0)
                                    .allowsHitTesting(false)
                            }

                            // Marker
                            Capsule()
                                .fill(Color.white)
                                .frame(width: markerW, height: 48)
                                .overlay(
                                    Capsule().strokeBorder(statusColor.opacity(0.85), lineWidth: 2.5)
                                )
                                .shadow(color: statusColor.opacity(0.8), radius: 8)
                                .offset(x: markerX)
                                .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: powerClash.progress)
                        }
                    }
                    .frame(height: 48)
                    // Bar outer glow when power-up is active
                    .shadow(color: activePowerUp != nil ? barGlowColor.opacity(0.6) : .clear, radius: 14)
                    .onChange(of: powerUpFlash) { flash in
                        guard flash != nil else { return }
                        withAnimation(.easeIn(duration: 0.1)) { barGlowOpacity = 0.45 }
                        withAnimation(.easeOut(duration: 0.5).delay(0.1)) { barGlowOpacity = 0 }
                    }

                    HStack {
                        Text("YOU")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "00e5ff"))
                            .shadow(color: .black, radius: 2)
                        Spacer()
                        Text("BOT")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(Color(hex: "e94560"))
                            .shadow(color: .black, radius: 2)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.bottom, 45)
            }
        }
    }

    @ViewBuilder
    private func pinZoneMarker(at x: CGFloat, barH: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 1.5, height: barH)
            .offset(x: x)
    }

    @ViewBuilder
    private func pendingPowerUpButton(_ type: PowerUpType) -> some View {
        // This button calls onCollectPowerUp — NOT onTap — so mashing never auto-collects
        Button(action: onCollectPowerUp) {
            HStack(spacing: 10) {
                Text(type.emoji)
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text("POWER-UP!")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(type.color.opacity(0.8))
                        .tracking(1.5)
                    Text(type.label)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
                Text("TAP ME!")
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(type.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(type.color.opacity(0.2))
                            .overlay(Capsule().strokeBorder(type.color.opacity(0.7), lineWidth: 1.5))
                    )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(type.color.opacity(0.7), lineWidth: 2)
                    )
            )
            .shadow(color: type.color.opacity(0.5), radius: 14)
        }
        .buttonStyle(.plain)
        .scaleEffect(tapPulse ? 1.05 : 0.96)
        .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: tapPulse)
    }

    @ViewBuilder
    private func activePowerUpBanner(_ active: ActivePowerUp) -> some View {
        let type = active.type
        let fraction = active.timeRemaining / type.duration
        HStack(spacing: 10) {
            Text(type.emoji)
                .font(.system(size: 20))
            Text(type.label)
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(type.color)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1)).frame(height: 6)
                    Capsule()
                        .fill(type.color)
                        .frame(width: geo.size.width * CGFloat(max(0, fraction)), height: 6)
                        .animation(.linear(duration: 0.1), value: active.timeRemaining)
                }
            }
            .frame(width: 80, height: 6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(Capsule().strokeBorder(type.color.opacity(0.5), lineWidth: 1.5))
        )
        .shadow(color: type.color.opacity(0.4), radius: 10)
    }
}
