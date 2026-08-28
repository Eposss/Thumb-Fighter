import Foundation
import SwiftUI

// GamePhase tracks what state the game is currently in.
enum GamePhase {
    case idle
    case powerClash
    case roundResult(won: Bool)
    case escaped
    case gameOver(won: Bool)
}

// PowerClash holds the live state of a tug-of-war clash.
struct PowerClash {
    var progress: Double = 0
}

// BotLevel defines how hard a specific opponent is.
struct BotLevel {
    let name: String
    let displayName: String
    let botReactionTime: Double
    let botPinchSpeed: Double
}

// The four opponents in order from easiest to hardest.
// BUFFED FOR MULTI-TOUCH MASHING
let gameLevels: [BotLevel] = [
    BotLevel(
        name: "easy",
        displayName: "Baby Thumb 👶",
        botReactionTime: 0.75,
        botPinchSpeed: 0.45
    ),
    BotLevel(
        name: "medium",
        displayName: "Street Brawler 🤜",
        botReactionTime: 0.4,
        botPinchSpeed: 0.85
    ),
    BotLevel(
        name: "hard",
        displayName: "Iron Grip 💪",
        botReactionTime: 0.3,
        botPinchSpeed: 1
    ),
    BotLevel(
        name: "expert",
        displayName: "Thumb God 👁️",
        botReactionTime: 0.18,
        botPinchSpeed: 1.5
    )
]

// HoldState tracks who currently has the upper hand during a clash.
// Equatable lets .animation(value:) skip re-renders when the value hasn't actually changed.
enum HoldState: Equatable {
    case none
    case playerHolding
    case botHolding
}

// PowerUp types available during a clash.
enum PowerUpType: CaseIterable {
    case speedBurst   // Player taps push the marker further
    case freeze       // Bot pressure stops for a few seconds
    case shield       // Marker can't move to bot's side temporarily

    var emoji: String {
        switch self {
        case .speedBurst: return "⚡"
        case .freeze:     return "❄️"
        case .shield:     return "🛡️"
        }
    }

    var label: String {
        switch self {
        case .speedBurst: return "SPEED BURST"
        case .freeze:     return "FREEZE"
        case .shield:     return "SHIELD"
        }
    }

    var color: Color {
        switch self {
        case .speedBurst: return Color(hex: "ffe600")
        case .freeze:     return Color(hex: "00e5ff")
        case .shield:     return Color(hex: "4cff72")
        }
    }

    var duration: Double {
        switch self {
        case .speedBurst: return 3.0
        case .freeze:     return 2.5
        case .shield:     return 3.5
        }
    }
}

// Active power-up state tracked by the engine.
struct ActivePowerUp {
    let type: PowerUpType
    var timeRemaining: Double
}
