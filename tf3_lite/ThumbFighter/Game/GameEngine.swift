import Foundation
import SwiftUI
import Combine

class GameEngine: ObservableObject {
    // Pre-loaded haptic engines — prepared immediately so first tap is never missed
    private let heavyHaptic = UIImpactFeedbackGenerator(style: .heavy)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)

    init() {
        heavyHaptic.prepare()
        lightHaptic.prepare()
    }
    // MARK: - Published State

    @Published var phase: GamePhase = .idle
    @Published var playerScore: Int = 0
    @Published var botScore: Int = 0
    @Published var currentLevel: Int = 0
    @Published var powerClash: PowerClash?
    @Published var playerThumbY: CGFloat = 0
    @Published var botThumbY: CGFloat = 0
    @Published var shakeScreen: Bool = false
    @Published var resultText: String = ""
    @Published var holdState: HoldState = .none
    @Published var clashCount: Int = 0
    @Published var pendingPowerUp: PowerUpType? = nil   // spawned, waiting for player tap
    @Published var activePowerUp: ActivePowerUp? = nil  // currently running effect
    @Published var powerUpFlash: PowerUpType? = nil     // triggers bar flash animation

    // MARK: - Thumb State Machine

    enum ThumbState { case up, striking, down, retreating }

    private var playerThumbState: ThumbState = .up
    private var botThumbState: ThumbState = .up

    // MARK: - Strike Window

    private var strikeWindowTimer: AnyCancellable?
    private var botAttackTimer: AnyCancellable?
    private var clashTimer: AnyCancellable?
    private var powerUpSpawnTimer: AnyCancellable?
    private var powerUpTickTimer: AnyCancellable?

    // Who is pinning who during a clash.
    // .player = player struck first, player is on top, bot is being pinned.
    // .bot    = bot struck first, bot is on top, player is being pinned.
    private var pinner: Side = .none

    enum Side { case player, bot, none }

    // MARK: - Constants

    var bot: BotLevel { gameLevels[min(currentLevel, gameLevels.count - 1)] }
    let maxScore: Int = 5

    private let clashFPS: Double = 30
    private let playerTapStrength: Double = 0.055   // was 0.11 — halved for slower feel
    private let botBasePressure: Double = 0.0021     // was 0.012 — halved to match

    // Power-up spawn interval range (seconds into a clash)
    private let powerUpSpawnMinDelay: Double = 2.0
    private let powerUpSpawnMaxDelay: Double = 5.0

    // 0.07s = ~14 taps/sec max — fast enough for one thumb, still caps 4-finger spam
    private let mashCooldown: TimeInterval = 0.005
    private var lastMashTime: TimeInterval = 0

    private let strikeWindowDuration: Double = 0.4

    // MARK: - Player Input

    func playerTapped() {
        switch phase {
        case .idle:       handlePlayerStrike()
        case .powerClash: applyPlayerMash()
        case .roundResult, .escaped: startNewRound()
        default: break
        }
    }

    // Called only from the dedicated power-up button in the UI
    func collectPowerUpTapped() {
        guard pendingPowerUp != nil, case .powerClash = phase else { return }
        collectPowerUp()
    }

    // MARK: - Strike Logic

    // Player taps while idle.
    // Rule: whoever's thumb was already down when the other arrives = the one being pinned.
    // So if bot is already down and player taps in → bot was first → BOT is pinner, player is pinned.
    // If bot is up and player taps → player is first → PLAYER is pinner, bot is pinned (if bot reacts).
    private func handlePlayerStrike() {
        guard playerThumbState == .up || playerThumbState == .retreating else { return }

        playerThumbState = .striking

        haptic(.heavy)
        animateThumbDown(player: true)

        switch botThumbState {
        case .down, .striking:
            // Bot's thumb was already extended — player tapped INTO bot's open window.
            // Bot struck first → player is the pinner
            cancelStrikeWindow()
            playerThumbState = .down
            triggerClash(pinner: .player)

        case .up, .retreating:
            // Bot wasn't down — player strikes first, opens a window.
            // If bot reacts within the window → bot is the pinner.
            playerThumbState = .down
            openStrikeWindow { [weak self] in
                self?.handleMiss()
            }
        }
    }

    // Bot strikes while idle — mirror of player logic.
    private func handleBotStrike() {
        guard botThumbState == .up, case .idle = phase else { return }

        botThumbState = .striking
        let duration = max(0.1, 0.5 - bot.botPinchSpeed * 0.4)
        animateThumbDown(player: false)

        // Wait for bot thumb animation to finish before checking/opening window.
        // This ensures the player can actually SEE the bot's thumb before the window closes.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, case .idle = self.phase else { return }

            switch self.playerThumbState {
            case .down, .striking:
                // Player already had thumb down while bot was animating — player was first.
                // Player is the pinner → bot is being pinned.
                self.cancelStrikeWindow()
                self.botThumbState = .down
                self.triggerClash(pinner: .bot)

            case .up, .retreating:
                // Bot's thumb has landed and player wasn't down — bot is first.
                // Open a window: if player reacts → bot is the pinner → player is being pinned.
                self.botThumbState = .down
                self.openStrikeWindow { [weak self] in
                    self?.handleMiss()
                }
            }
        }
    }

    // When the window is open and the OTHER side taps in, they walked into the strike.
    // The one who opened the window is the pinner.
    // This is called from handlePlayerStrike when bot was already down (bot opened window → bot pins).
    // And from the delayed check in handleBotStrike when player was already down (player opened → player pins).
    // The triggerClash calls above already encode this correctly via the pinner: argument.

    private func openStrikeWindow(onExpire: @escaping () -> Void) {
        strikeWindowTimer?.cancel()
        strikeWindowTimer = Just(())
            .delay(for: .seconds(strikeWindowDuration), scheduler: RunLoop.main)
            .sink { onExpire() }
    }

    private func cancelStrikeWindow() {
        strikeWindowTimer?.cancel()
        strikeWindowTimer = nil
    }

    private func handleMiss() {
        cancelStrikeWindow()
        playerThumbState = .up
        botThumbState = .up
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            playerThumbY = 0
            botThumbY = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, case .idle = self.phase else { return }
            self.scheduleBotAttack()
        }
    }

    // MARK: - Thumb Animation

    private func animateThumbDown(player: Bool) {
        let duration = player ? 0.18 : max(0.1, 0.5 - bot.botPinchSpeed * 0.4)
        withAnimation(.spring(response: duration, dampingFraction: 0.6)) {
            if player { playerThumbY = 1.0 } else { botThumbY = 1.0 }
        }
    }

    // MARK: - Power Clash

    // pinner: who struck first and is on top.
    // .player = player is on top pressing bot down → playerHolding, progress starts at +0.5
    // .bot    = bot is on top pressing player down → botHolding, progress starts at -0.5
    private func triggerClash(pinner: Side) {
        stopBotAttackTimer()
        haptic(.heavy)
        shakeScreen = true
        clashCount += 1

        self.pinner = pinner

        let initialProgress: Double
        switch pinner {
        case .player:
            initialProgress = 0.0
            resultText = "YOU PINNED THEM! HOLD IT DOWN!"
        case .bot:
            initialProgress = -0.5
            resultText = "YOU GOT PINNED! FIGHT BACK!"
        case .none:
            initialProgress = 0.0
            resultText = "MASH TO OVERPOWER!"
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.shakeScreen = false
        }

        var clash = PowerClash()
        clash.progress = initialProgress
        powerClash = clash

        // .playerHolding = player's thumb is on top, pressing bot down
        // .botHolding    = bot's thumb is on top, pressing player down
        switch pinner {
        case .player: holdState = .playerHolding
        case .bot:    holdState = .botHolding
        case .none:   holdState = .none
        }

        phase = .powerClash
        startPowerClashLoop()
        schedulePowerUpSpawn()
    }

    private func startPowerClashLoop() {
        clashTimer?.cancel()
        clashTimer = Timer.publish(every: 1 / clashFPS, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.advanceBotPressure() }
    }

    private func advanceBotPressure() {
        guard var clash = powerClash, case .powerClash = phase else { return }

        // FREEZE: bot pressure paused
        if activePowerUp?.type == .freeze { return }

        let randomSwing = Double.random(in: -0.003...0.007)
        let pressure = botBasePressure + Double(bot.botPinchSpeed) * 0.026 + randomSwing

        var newProgress = clash.progress - pressure

        // SHIELD: clamp so marker can't go past centre to bot's side
        if activePowerUp?.type == .shield {
            newProgress = max(0, newProgress)
        }

        clash.progress = max(-1, min(1, newProgress))
        powerClash = clash
        evaluateClash(progress: clash.progress)
    }

    private func applyPlayerMash() {
        guard var clash = powerClash, case .powerClash = phase else { return }

        let now = Date.timeIntervalSinceReferenceDate
        guard now - lastMashTime >= mashCooldown else { return }
        lastMashTime = now

        // SPEED BURST: 1.6x tap strength (not 2x — base is already slower)
        let strength = activePowerUp?.type == .speedBurst ? playerTapStrength * 1.6 : playerTapStrength
        clash.progress = max(-1, min(1, clash.progress + strength))
        powerClash = clash

        haptic(.light)
        evaluateClash(progress: clash.progress)
    }

    private func evaluateClash(progress: Double) {
        if progress >= 1 { playerWinsClash() }
        else if progress <= -1 { botWinsClash() }
    }

    // Player pushed bar to +1.
    private func playerWinsClash() {
        clashTimer?.cancel()
        haptic(.success)

        if pinner == .bot {
            // Player was being pinned but fought all the way back — escape
            resultText = "YOU BROKE FREE! 💥"
            phase = .escaped
            resetClashState()
            retreatBothThumbs()
            return
        }

        // Player was the pinner and held it — score
        playerScore += 1
        resultText = "CRUSHED THEM! POINT TO YOU! 👊"
        if playerScore >= maxScore { triggerKO(playerWon: true); return }
        returnToNeutral()
    }

    // Bot pushed bar to -1.
    private func botWinsClash() {
        clashTimer?.cancel()
        haptic(.error)

        if pinner == .player {
            // Bot was being pinned but fought all the way back — escape
            resultText = "BOT BROKE FREE! 💥"
            phase = .escaped
            resetClashState()
            retreatBothThumbs()
            return
        }

        // Bot was the pinner and held it — score
        botScore += 1
        resultText = "BOT OVERPOWERED YOU! POINT TO BOT!"
        if botScore >= maxScore { triggerKO(playerWon: false); return }
        returnToNeutral()
    }

    // MARK: - Power-Up System

    private func schedulePowerUpSpawn() {
        powerUpSpawnTimer?.cancel()
        let delay = Double.random(in: powerUpSpawnMinDelay...powerUpSpawnMaxDelay)
        powerUpSpawnTimer = Just(())
            .delay(for: .seconds(delay), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self, case .powerClash = self.phase, self.pendingPowerUp == nil else { return }
                self.pendingPowerUp = self.randomPowerUpType()
                // Auto-dismiss after 3 seconds if not collected
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self, case .powerClash = self.phase else { return }
                    if self.pendingPowerUp != nil {
                        self.pendingPowerUp = nil
                        self.schedulePowerUpSpawn()
                    }
                }
            }
    }

    private func randomPowerUpType() -> PowerUpType {
        let roll = Double.random(in: 0..<1)

        switch roll {
        case ..<0.4:
            return .speedBurst
        case ..<0.65:
            return .freeze
        default:
            return .shield
        }
    }

    private func collectPowerUp() {
        guard let type = pendingPowerUp else { return }
        pendingPowerUp = nil
        powerUpSpawnTimer?.cancel()
        haptic(.success)
        activatePowerUp(type)
        // Schedule next spawn after this power-up expires
        DispatchQueue.main.asyncAfter(deadline: .now() + type.duration + 1.5) { [weak self] in
            guard let self, case .powerClash = self.phase else { return }
            self.schedulePowerUpSpawn()
        }
    }

    private func activatePowerUp(_ type: PowerUpType) {
        activePowerUp = ActivePowerUp(type: type, timeRemaining: type.duration)
        powerUpFlash = type
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.powerUpFlash = nil
        }
        powerUpTickTimer?.cancel()
        powerUpTickTimer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                guard var active = self.activePowerUp else { self.powerUpTickTimer?.cancel(); return }
                active.timeRemaining -= 0.1
                if active.timeRemaining <= 0 {
                    self.activePowerUp = nil
                    self.powerUpTickTimer?.cancel()
                } else {
                    self.activePowerUp = active
                }
            }
    }

    private func clearPowerUps() {
        pendingPowerUp = nil
        activePowerUp = nil
        powerUpFlash = nil
        powerUpSpawnTimer?.cancel()
        powerUpTickTimer?.cancel()
    }

    private func resetClashState() {
        powerClash = nil
        holdState = .none
        pinner = .none
        clearPowerUps()
    }

    private func returnToNeutral() {
        resetClashState()
        phase = .idle
        retreatBothThumbs()
    }

    private func triggerKO(playerWon: Bool) {
        resetClashState()
        haptic(playerWon ? .success : .error)
        phase = .gameOver(won: playerWon)
    }

    // MARK: - Bot AI

    func startBotBehaviour() {
        stopBotAttackTimer()
        scheduleBotAttack()
    }

    func stopBot() {
        stopBotAttackTimer()
    }

    private func scheduleBotAttack() {
        let interval = bot.botReactionTime + Double.random(in: 0..<0.2)
        botAttackTimer = Just(())
            .delay(for: .seconds(max(0.15, interval)), scheduler: RunLoop.main)
            .sink { [weak self] in
                guard let self, case .idle = self.phase else { return }
                self.handleBotStrike()
            }
    }

    private func stopBotAttackTimer() {
        botAttackTimer?.cancel()
        botAttackTimer = nil
    }

    private func retreatBothThumbs() {
        playerThumbState = .up
        botThumbState = .up
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
            playerThumbY = 0
            botThumbY = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, case .idle = self.phase else { return }
            self.scheduleBotAttack()
        }
    }

    // MARK: - Round / Game Flow

    func startNewRound() {
        clashTimer?.cancel()
        cancelStrikeWindow()
        resetClashState()
        playerThumbState = .up
        botThumbState = .up
        withAnimation { playerThumbY = 0; botThumbY = 0 }
        phase = .idle
        startBotBehaviour()
    }

    func startGame(level: Int = 0) {
        currentLevel = level
        playerScore = 0
        botScore = 0
        clashCount = 0
        resultText = ""
        
        AudioManager.shared.playBGM(filename: "bgm", ext: "mp3")
        startNewRound()
    }

    func nextLevel() {
        currentLevel += 1
        playerScore = 0
        botScore = 0
        clashCount = 0
        resultText = ""
        startNewRound()
    }

    func restartGame() {
        stopBotAttackTimer()
        clashTimer?.cancel()
        startGame(level: 0)
    }

    // MARK: - Haptics

    private func haptic(_ style: HapticStyle) {
        switch style {
        case .heavy:
            heavyHaptic.impactOccurred()
            heavyHaptic.prepare()  // warm up for next hit
        case .light:
            lightHaptic.impactOccurred()
            lightHaptic.prepare()  // warm up for next mash tap
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
    
    enum HapticStyle { case heavy, light, success, error }
}
