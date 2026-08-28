import SwiftUI

// ThumbArenaView is the visual battle scene.
struct ThumbArenaView: View {
    let playerThumbY: CGFloat
    let botThumbY: CGFloat
    let phase: GamePhase
    let holdState: HoldState

    private let baseFistWidth: CGFloat = 300.0
    private let baseThumbSize = CGSize(width: 60, height: 120)

    private let playerXOffset: CGFloat = -70.0
    private let botXOffset: CGFloat = 50.0
    private let thumbsYOffset: CGFloat = -135

    private var playerThumbPinOffset: CGFloat {
        switch holdState {
        case .botHolding:    return 20
        case .playerHolding: return -10
        case .none:          return 0
        }
    }
    private var botThumbPinOffset: CGFloat {
        switch holdState {
        case .playerHolding: return 20
        case .botHolding:    return -10
        case .none:          return 0
        }
    }

    private var playerThumbScale: CGFloat { holdState == .botHolding ? 0.88 : 1.0 }
    private var botThumbScale: CGFloat { holdState == .playerHolding ? 0.88 : 1.0 }

    var body: some View {
        GeometryReader { geo in
            let targetSize = CGSize(width: 380, height: 300)
            let scale = min(geo.size.width / targetSize.width, geo.size.height / targetSize.height)

            ZStack {
                // Stage floor shadow
                Ellipse()
                    .fill(Color.black.opacity(0.5))
                    .frame(width: baseFistWidth * 0.9, height: 40)
                    .offset(y: 80)

                // Fists Image — the anchor
                Image("fists")
                    .resizable()
                    .scaledToFit()
                    .frame(width: baseFistWidth)
                    .shadow(color: Color.black.opacity(0.4), radius: 8, x: 0, y: 6)

                // Player Thumb (Blue)
                ThumbView(imageName: "player_thumb", thumbPress: playerThumbY, isBot: false)
                    .frame(width: baseThumbSize.width, height: baseThumbSize.height)
                    .scaleEffect(x: 1, y: playerThumbScale, anchor: .bottom)
                    .offset(x: playerXOffset, y: thumbsYOffset + playerThumbPinOffset)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: holdState)

                // Bot Thumb (Red)
                ThumbView(imageName: "bot_thumb", thumbPress: botThumbY, isBot: true)
                    .frame(width: baseThumbSize.width, height: baseThumbSize.height)
                    .scaleEffect(x: 1, y: botThumbScale, anchor: .bottom)
                    .offset(x: botXOffset, y: thumbsYOffset + botThumbPinOffset)
                    .animation(.spring(response: 0.25, dampingFraction: 0.6), value: holdState)

                // Pin Badges
                if holdState == .botHolding {
                    pinnedBadge.offset(x: playerXOffset, y: thumbsYOffset - 80)
                }
                if holdState == .playerHolding {
                    pinnedBadge.offset(x: botXOffset, y: thumbsYOffset - 80)
                }

                // Fight Burst
                if phase.isPowerClash {
                    // MOVED HIGHER: Changed offset from -80 to -160
                    FightBurst().offset(y: -160)
                }
            }
            .scaleEffect(scale)
            .position(x: geo.size.width / 2, y: geo.size.height * 0.65)
        }
    }

    private var pinnedBadge: some View {
        Text("📌 PINNED")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(Color(hex: "ff6b6b"))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.8))
                    .overlay(Capsule().strokeBorder(Color(hex: "ff6b6b").opacity(0.8), lineWidth: 1.5))
            )
            .shadow(color: Color(hex: "ff6b6b").opacity(0.4), radius: 6)
            .transition(.scale.combined(with: .opacity))
    }
}

struct ThumbView: View {
    let imageName: String
    let thumbPress: CGFloat
    let isBot: Bool

    var body: some View {
        let press = min(max(thumbPress, 0), 1)
        let angle = isBot ? (0.0 - (press * 60.0)) : (0.0 + (press * 60.0))
        let anchor = UnitPoint(x: 0.5, y: 1.0)

        return Image(imageName)
            .resizable()
            .scaledToFit()
            .rotationEffect(.degrees(angle), anchor: anchor)
    }
}

struct FightBurst: View {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            ForEach(0..<8) { i in
                Rectangle()
                    .fill(Color(hex: "ffe600").opacity(0.4))
                    .frame(width: 4, height: 60)
                    .offset(y: -30)
                    .rotationEffect(.degrees(Double(i) * 45))
            }
            Text("FIGHT!")
                .font(.system(size: 44, weight: .black, design: .rounded))
                .italic()
                .foregroundColor(Color(hex: "ffe600"))
                .shadow(color: .black, radius: 0, x: 2, y: 3)
                .shadow(color: Color(hex: "e94560"), radius: 12)
        }
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5)) {
                scale = 1.1; opacity = 1
            }
        }
    }
}

extension GamePhase {
    var isPowerClash: Bool {
        if case .powerClash = self { return true }
        return false
    }
}
