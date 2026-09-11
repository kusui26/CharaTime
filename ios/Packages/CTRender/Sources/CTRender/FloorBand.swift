import SwiftUI
import CTCore

/// 歩ける帯の上辺と下辺（画面の高さに対する比）。
///
/// **View から切り離した純粋な値にしてある。** 指の位置を帯に直す規則が
/// いちばん間違えやすいので、ここだけをテストすれば足りるようにする。
public struct FloorBand: Sendable, Equatable {

    public enum Edge: CaseIterable, Sendable {
        case top, bottom

        var title: String {
            switch self {
            case .top: "おく"
            case .bottom: "てまえ"
            }
        }
    }

    /// 帯の最小の厚み。これより薄いと歩く余地が無く、奥行きの縮尺も効かない。
    public static let minimumHeight: Double = 0.06
    /// 帯を置ける範囲。上は時計に、下は画面の縁にかからないようにする。
    public static let allowed: ClosedRange<Double> = 0.18...0.98

    public private(set) var top: Double
    public private(set) var bottom: Double

    public init(top: Double, bottom: Double) {
        let clampedTop = Swift.min(Swift.max(top, Self.allowed.lowerBound),
                                   Self.allowed.upperBound - Self.minimumHeight)
        self.top = clampedTop
        self.bottom = Swift.min(Swift.max(bottom, clampedTop + Self.minimumHeight),
                                Self.allowed.upperBound)
    }

    public var height: Double { bottom - top }

    public func value(of edge: Edge) -> Double {
        switch edge {
        case .top: top
        case .bottom: bottom
        }
    }

    /// 片方の辺を動かす。**もう片方は動かさず、最小の厚みを守る。**
    public func moving(_ edge: Edge, to position: Double) -> FloorBand {
        switch edge {
        case .top:
            FloorBand(top: Swift.min(position, bottom - Self.minimumHeight), bottom: bottom)
        case .bottom:
            FloorBand(top: top, bottom: Swift.max(position, top + Self.minimumHeight))
        }
    }

    public var rect: RoomRect {
        RoomRect(x: 0, y: top, width: 1, height: height)
    }
}

/// 帯の外を暗くして、選んでいる範囲を示す覆い。
struct FloorBandOverlay: View {

    let band: FloorBand
    let size: CGSize
    let dragging: FloorBand.Edge?

    /// 帯の外を暗くする濃さ。
    private static let outsideDimming: Double = 0.45

    var body: some View {
        Canvas { context, canvasSize in
            let top = band.top * canvasSize.height
            let bottom = band.bottom * canvasSize.height
            context.fill(Path(CGRect(x: 0, y: 0, width: canvasSize.width, height: top)),
                         with: .color(.black.opacity(Self.outsideDimming)))
            context.fill(Path(CGRect(x: 0, y: bottom, width: canvasSize.width,
                                     height: canvasSize.height - bottom)),
                         with: .color(.black.opacity(Self.outsideDimming)))
            for edge in [top, bottom] {
                context.fill(Path(CGRect(x: 0, y: edge - 1, width: canvasSize.width, height: 2)),
                             with: .color(.white.opacity(0.9)))
            }
        }
        .allowsHitTesting(false)
    }
}

/// 指でつまむ取っ手。指で押さえやすい高さを確保する。
struct FloorBandHandle: View {

    let title: String
    let isActive: Bool

    /// 指の当たり判定の高さ。Apple の指針の 44pt に合わせる。
    private static let hitHeight: Double = 44

    var body: some View {
        ZStack {
            Color.clear.frame(height: Self.hitHeight)
            HStack(spacing: 7) {
                Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .bold))
                Text(title).font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.black.opacity(0.75))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Capsule().fill(.white.opacity(isActive ? 1 : 0.88)))
            .scaleEffect(isActive ? 1.08 : 1)
            .animation(.easeOut(duration: 0.12), value: isActive)
        }
        .contentShape(Rectangle())
    }
}

/// 決める・やめるのボタン。
struct FloorBandControls: View {

    let onDone: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack {
            HStack {
                button("やめる", filled: false, action: onCancel)
                Spacer()
                button("きめる", filled: true, action: onDone)
            }
            .padding(.horizontal, 20)
            .padding(.top, 72)
            Spacer()
            Text("キャラクターが歩く帯を、上下の取っ手で決めてください")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(.black.opacity(0.5)))
                .padding(.bottom, 46)
        }
    }

    private func button(_ title: String, filled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(filled ? .white : .black.opacity(0.8))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Capsule().fill(filled ? Color(hex: 0xE08A4E) : .white.opacity(0.9)))
        }
        .buttonStyle(.plain)
    }
}
