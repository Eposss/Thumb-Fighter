import SwiftUI

// GameView — root game screen, iPhone 17 safe-area aware.
struct GameView: View {
    @StateObject private var engine = GameEngine()
    @State private var showLevelSelect = true
    @State private var screenShakeOffset: CGFloat = 0

    var body: some View {
        ZStack {
            // The red/blue gradient is now the full screen background
            GameBackground()

            if showLevelSelect {
                GeometryReader { geo in
                    LevelSelectView { level in
                        withAnimation(.spring()) { showLevelSelect = false }
                        engine.startGame(level: level)
                    }
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 8)
                }
            } else {
                mainGameContent
                    .offset(x: screenShakeOffset)
                    .onChange(of: engine.shakeScreen) { shaking in
                        if shaking { triggerShakeAnimation() }
                    }
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Main game layout
    private var mainGameContent: some View {
        GeometryReader { geo in
            ZStack {
                VStack(spacing: 0) {
                    // HUD — sits just below Dynamic Island / notch
                    HUDView(
                        playerScore: engine.playerScore,
                        botScore: engine.botScore,
                        maxScore: engine.maxScore,
                        levelName: gameLevels[min(engine.currentLevel, gameLevels.count - 1)].displayName,
                        clashCount: engine.clashCount
                    )
                    .padding(.top, geo.safeAreaInsets.top + 8)
                    .padding(.horizontal, 20)

                    Spacer()

                    // Arena — takes up a comfortable fixed slice of the screen
                    ThumbArenaView(
                        playerThumbY: engine.playerThumbY,
                        botThumbY: engine.botThumbY,
                        phase: engine.phase,
                        holdState: engine.holdState
                                        )
                    // INCREASED HEIGHT HERE: Changed from 0.42 to 0.65
                    .frame(height: min(geo.size.height * 0.5, 380))

                    Spacer()

                    // Tap hint — shown above the mash zone
                    Group {
                        if case .idle = engine.phase {
                            Text("TAP ANYWHERE TO STRIKE! 👇")
                                .font(.system(size: 20, weight: .bold, design: .rounded)) // Made slightly larger
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.5), radius: 4)
                        } else if case .escaped = engine.phase {
                            Text("💥 PIN BROKEN — TAP TO CONTINUE")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "4cff72"))
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            Text(" ").font(.system(size: 20))
                        }
                    }
                    .padding(.bottom, geo.safeAreaInsets.bottom + 100)
                }

                // Full-screen instant tap target
                RapidTapView { engine.playerTapped() }
                    .ignoresSafeArea()

                phaseOverlay
            }
        }
    }

    // MARK: - Phase Overlays
    @ViewBuilder
    private var phaseOverlay: some View {
        switch engine.phase {
        case .powerClash:
            if let clash = engine.powerClash {
                PowerClashView(
                    powerClash: clash,
                    holdState: engine.holdState,
                    pendingPowerUp: engine.pendingPowerUp,
                    activePowerUp: engine.activePowerUp,
                    powerUpFlash: engine.powerUpFlash,
                    onTap: { engine.playerTapped() },
                    onCollectPowerUp: { engine.collectPowerUpTapped() }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        case .roundResult(let won):
            RoundResultView(
                text: engine.resultText,
                won: won,
                onContinue: { engine.playerTapped() }
            )
            .transition(.scale.combined(with: .opacity))
        case .gameOver(let won):
            GameOverView(
                won: won,
                level: engine.currentLevel,
                onNextLevel: {
                    if won { engine.nextLevel() }
                    else { engine.restartGame() }
                },
                onMenu: {
                    engine.stopBot()
                    showLevelSelect = true
                }
            )
            .transition(.scale.combined(with: .opacity))
        default:
            EmptyView()
        }
    }

    private func triggerShakeAnimation() {
        let steps: [CGFloat] = [8, -8, 6, -6, 3, 0]
        var delay = 0.0
        for step in steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.linear(duration: 0.05)) {
                    screenShakeOffset = step
                }
            }
            delay += 0.05
        }
    }
}

// MARK: - Game Background
// drawingGroup() rasterises everything into one GPU texture so SwiftUI
// never redraws this during gameplay — it has no state that changes.
struct GameBackground: View {
    var body: some View {
        ZStack {
            Color(hex: "0d0820")

            RadialGradient(
                colors: [Color(hex: "00e5ff").opacity(0.28), .clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 500
            )

            RadialGradient(
                colors: [Color(hex: "e94560").opacity(0.28), .clear],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 500
            )

            // Grid — Canvas already batches drawing; no GeometryReader needed
            Canvas { ctx, size in
                let spacing: CGFloat = 40
                var path = Path()
                var x: CGFloat = 0
                while x < size.width  { path.move(to: .init(x: x, y: 0)); path.addLine(to: .init(x: x, y: size.height)); x += spacing }
                var y: CGFloat = 0
                while y < size.height { path.move(to: .init(x: 0, y: y)); path.addLine(to: .init(x: size.width, y: y));  y += spacing }
                ctx.stroke(path, with: .color(.white.opacity(0.04)), lineWidth: 1)
            }
        }
        .drawingGroup()  // flattens to a single Metal texture — never redrawn during gameplay
    }
}
