import SwiftUI
import UIKit

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// gameFont kept as a no-op redirect to SF Rounded for any callers still using it
extension View {
    func gameFont(size: CGFloat) -> some View {
        self.font(.system(size: size, weight: .black, design: .rounded))
    }
}

// MARK: - Rapid Tap Target
// Bypasses SwiftUI's gesture delays for instant, multi-touch mashing.
struct RapidTapView: UIViewRepresentable {
    var onTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = RapidTapUIView()
        view.onTap = onTap
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

class RapidTapUIView: UIView {
    var onTap: (() -> Void)?

    init() {
        super.init(frame: .zero)
        // Enable this so players can drum with two fingers!
        self.isMultipleTouchEnabled = true
        self.backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        // Trigger the tap action for every single finger that touches down
        for _ in touches {
            onTap?()
        }
    }
}
