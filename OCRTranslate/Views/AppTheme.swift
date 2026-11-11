import SwiftUI
import UIKit

// MARK: - 主题色板(与口袋网页版同一套视觉)

extension Color {
    static let ptBG = Color(red: 0.027, green: 0.039, blue: 0.071)
    static let ptText = Color(red: 0.93, green: 0.94, blue: 0.97)
    static let ptSub = Color(red: 0.60, green: 0.64, blue: 0.73)
    static let ptAccent = Color(red: 0.31, green: 0.49, blue: 1.0)
    static let ptAccent2 = Color(red: 0.61, green: 0.36, blue: 1.0)
    static let ptLine = Color.white.opacity(0.10)
    static let ptField = Color.white.opacity(0.07)
    static let ptDanger = Color(red: 1.0, green: 0.42, blue: 0.42)
}

// MARK: - 星空背景(星云 + 确定性星点)

struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

struct PTBackground: View {
    var body: some View {
        ZStack {
            Color.ptBG
            RadialGradient(
                colors: [Color.ptAccent2.opacity(0.22), .clear],
                center: UnitPoint(x: 0.92, y: -0.08),
                startRadius: 10,
                endRadius: 780
            )
            RadialGradient(
                colors: [Color.ptAccent.opacity(0.16), .clear],
                center: UnitPoint(x: -0.05, y: 0.32),
                startRadius: 10,
                endRadius: 640
            )
            Starfield()
        }
        .ignoresSafeArea()
    }
}

struct Starfield: View {
    var body: some View {
        Canvas { context, size in
            var rng = SeededRandom(seed: 2026)
            for _ in 0..<110 {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let r = CGFloat.random(in: 0.5...1.6, using: &rng)
                let a = Double.random(in: 0.2...0.8, using: &rng)
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)),
                    with: .color(.white.opacity(a))
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - 毛玻璃卡片

struct PTCard: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Color.ptLine, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }
}

extension View {
    func ptCard(padding: CGFloat = 16) -> some View {
        modifier(PTCard(padding: padding))
    }

    func ptInnerCard() -> some View {
        padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.ptField)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.ptLine, lineWidth: 1)
                    )
            )
    }
}

// MARK: - 渐变主按钮

struct PTGradientButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button {
            haptic()
            action()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title).font(.system(size: 16, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [.ptAccent, .ptAccent2], startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .foregroundColor(.white)
            .shadow(color: Color.ptAccent2.opacity(0.38), radius: 12, y: 6)
        }
    }
}

// MARK: - 输入框样式

struct PTTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.ptField)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.ptLine, lineWidth: 1)
                    )
            )
            .foregroundColor(.ptText)
            .font(.system(size: 15))
    }
}

// MARK: - 触感反馈

func haptic() {
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
}

func hapticSuccess() {
    UINotificationFeedbackGenerator().notificationOccurred(.success)
}

// MARK: - 系统外观(透明导航栏 / 深色标签栏)

enum AppTheme {
    static func configureAppearance() {
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 20, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
        UITabBar.appearance().tintColor = UIColor(red: 0.58, green: 0.65, blue: 1.0, alpha: 1.0)
        UITabBar.appearance().unselectedItemTintColor = UIColor(white: 1.0, alpha: 0.45)
    }
}
