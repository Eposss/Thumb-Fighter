import SwiftUI

// MARK: - HUD
struct HUDView: View {
    let playerScore: Int
    let botScore: Int
    let maxScore: Int
    let levelName: String
    let clashCount: Int

    private var heatLevel: Int { min(clashCount / 3, 3) }
    private var heatColor: Color {
        [Color(hex: "4cff72"), Color(hex: "ffe600"), Color(hex: "ff9900"), Color(hex: "e94560")][heatLevel]
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )

            HStack(spacing: 0) {
                FighterScoreBar(
                    current: playerScore, max: maxScore,
                    label: "YOU", color: Color(hex: "00e5ff"), flipped: false
                )

                // Center badge - Larger Fonts applied here
                VStack(spacing: 4) {
                    Text("THUMB FIGHTER")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(2)

                    HStack(spacing: 4) {
                        ForEach(0..<4) { i in
                            Circle()
                                .fill(i <= heatLevel ? heatColor : Color.white.opacity(0.15))
                                .frame(width: 8, height: 8)
                        }
                    }
                    .animation(.easeInOut, value: heatLevel)

                    Text(levelName)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .frame(width: 160) // Widened to fit the larger text

                FighterScoreBar(
                    current: botScore, max: maxScore,
                    label: "BOT", color: Color(hex: "e94560"), flipped: true
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            // Heat accent line at bottom of pill
            VStack {
                Spacer()
                Capsule()
                    .fill(heatColor)
                    .frame(height: 4)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 6)
                    .animation(.easeInOut, value: heatLevel)
            }
        }
        .frame(height: 85) // Height increased to accommodate larger fonts
    }
}

// MARK: - Score Bar
struct FighterScoreBar: View {
    let current: Int
    let max: Int
    let label: String
    let color: Color
    let flipped: Bool

    var body: some View {
        VStack(alignment: flipped ? .trailing : .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 16, weight: .black, design: .rounded)) // Larger label
                    .foregroundColor(.white)
                Text("\(current)/\(max)")
                    .font(.system(size: 14, weight: .bold, design: .rounded)) // Larger numbers
                    .foregroundColor(color)
            }

            GeometryReader { geo in
                ZStack(alignment: flipped ? .trailing : .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 12) // Slightly thicker bar

                    Capsule()
                        .fill(LinearGradient(
                            colors: scoreColors,
                            startPoint: flipped ? .trailing : .leading,
                            endPoint: flipped ? .leading : .trailing
                        ))
                        .frame(
                            width: geo.size.width * CGFloat(current) / CGFloat(max),
                            height: 12
                        )
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: current)
                }
            }
            .frame(height: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
    }

    private var scoreColors: [Color] {
        let ratio = Double(current) / Double(max)
        if ratio > 0.5  { return [Color(hex: "4cff72"), Color(hex: "00e5a0")] }
        if ratio > 0.25 { return [Color(hex: "ffe600"), Color(hex: "ff9900")] }
        return [Color(hex: "ff3d3d"), Color(hex: "e94560")]
    }
}

// MARK: - Round Result
struct RoundResultView: View {
    let text: String
    let won: Bool
    let onContinue: () -> Void

    @State private var scale: CGFloat = 0.6
    @State private var opacity: Double = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 18) {
                Text(text)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(won ? Color(hex: "4cff72") : Color(hex: "ff6b6b"))
                    .multilineTextAlignment(.center)
                    .shadow(color: (won ? Color(hex: "4cff72") : Color(hex: "ff6b6b")).opacity(0.7), radius: 14)

                Text("Tap anywhere to continue")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 30)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                (won ? Color(hex: "4cff72") : Color(hex: "ff6b6b")).opacity(0.4),
                                lineWidth: 1.5
                            )
                    )
            )
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
                scale = 1; opacity = 1
            }
        }
        .onTapGesture { onContinue() }
    }
}

// MARK: - Game Over
struct GameOverView: View {
    let won: Bool
    let level: Int
    let onNextLevel: () -> Void
    let onMenu: () -> Void

    private var isLastLevel: Bool { level >= gameLevels.count - 1 }

    var body: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()

            VStack(spacing: 22) {
                Text(won ? "🏆" : "💀")
                    .font(.system(size: 60))

                Text(won ? "VICTORY!" : "DEFEATED!")
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundColor(won ? Color(hex: "ffe600") : Color(hex: "ff6b6b"))
                    .shadow(color: (won ? Color(hex: "ffe600") : Color(hex: "ff6b6b")).opacity(0.6), radius: 18)

                if won && isLastLevel {
                    Text("You beat every opponent!\nThumb Champion! 👑")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 10) {
                    if won && !isLastLevel {
                        GameButton(label: "NEXT OPPONENT →", color: Color(hex: "4cff72"), action: onNextLevel)
                    } else if won && isLastLevel {
                        GameButton(label: "PLAY AGAIN", color: Color(hex: "ffe600"), action: onNextLevel)
                    } else {
                        GameButton(label: "TRY AGAIN", color: Color(hex: "e94560"), action: onNextLevel)
                    }
                    GameButton(label: "MAIN MENU", color: Color.white.opacity(0.2), action: onMenu)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .strokeBorder(
                                (won ? Color(hex: "ffe600") : Color(hex: "e94560")).opacity(0.35),
                                lineWidth: 1.5
                            )
                    )
            )
            .padding(.horizontal, 28)
        }
    }
}

// MARK: - Level Select
struct LevelSelectView: View {
    let onStart: (Int) -> Void
    @State private var selectedLevel = 0

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("👍🤜")
                            .font(.system(size: 44))
                        Text("THUMB FIGHTER")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, Color(hex: "e94560")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color(hex: "e94560").opacity(0.5), radius: 12)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 28)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("CHOOSE YOUR OPPONENT")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.4))
                            .tracking(2)
                            .padding(.bottom, 2)

                        ForEach(Array(gameLevels.enumerated()), id: \.offset) { idx, level in
                            LevelRow(level: level, index: idx, isSelected: selectedLevel == idx) {
                                selectedLevel = idx
                            }
                        }
                    }
                    // ADDED: Using safeAreaInsets to pad the left and right sides
                    .padding(.leading, max(20, geometry.safeAreaInsets.leading + 20))
                    .padding(.trailing, max(20, geometry.safeAreaInsets.trailing + 20))

                    Spacer(minLength: 40)

                    GameButton(label: "FIGHT! ⚡", color: Color(hex: "e94560"), action: {
                        onStart(selectedLevel)
                    })
                    // ADDED: Same safe area padding for the button
                    .padding(.leading, max(28, geometry.safeAreaInsets.leading + 28))
                    .padding(.trailing, max(28, geometry.safeAreaInsets.trailing + 28))
                    .padding(.bottom, max(40, geometry.safeAreaInsets.bottom + 20))
                }
                .frame(minHeight: geometry.size.height)
            }
        }
    }
}

// MARK: - Level Row
struct LevelRow: View {
    let level: BotLevel
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void

    private let diffColors: [Color] = [
        Color(hex: "4cff72"),
        Color(hex: "ffe600"),
        Color(hex: "ff9900"),
        Color(hex: "ff3d3d")
    ]

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(level.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Spacer()
                HStack(spacing: 5) {
                    ForEach(0..<4) { i in
                        Circle()
                            .fill(i <= index ? diffColors[index] : Color.white.opacity(0.15))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? diffColors[index].opacity(0.15) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(
                                isSelected ? diffColors[index].opacity(0.6) : Color.white.opacity(0.1),
                                lineWidth: 1.5
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Game Button
struct GameButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(color.opacity(0.22))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(color.opacity(0.75), lineWidth: 1.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .shadow(color: color.opacity(0.3), radius: 8, y: 4)
    }
}
