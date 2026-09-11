import Foundation

/// 絵を足さずに「生きている」ように見せる味付け（プラン §5.5）。
///
/// 11 枚のコマだけでは、どうしても動きが足りない。呼吸・弾み・首のかしげを
/// **時刻の関数**として足すことで、絵を増やさずに表情を増やす。
///
/// **状態を持たないことが要点。** だから待受モードで 60fps 描いても、
/// ウィジェットが 3 時間後の 1 枚を描いても、同じ時刻なら同じ姿になる。
public struct Flourish: Sendable, Equatable {

    /// 地面から浮く高さ（キャラの身長に対する比）。
    public var liftRatio: Double
    /// 横に伸びる倍率（1.0 が素）。
    public var stretchX: Double
    /// 縦に伸びる倍率。
    public var stretchY: Double
    /// 傾き（度。正で右へ倒れる）。
    public var tiltDegrees: Double
    /// 影の大きさの倍率。浮くと小さくなる。
    public var shadowScale: Double
    /// 影の濃さの倍率。浮くと薄くなる。
    public var shadowOpacity: Double

    public init(liftRatio: Double = 0, stretchX: Double = 1, stretchY: Double = 1,
                tiltDegrees: Double = 0, shadowScale: Double = 1, shadowOpacity: Double = 1) {
        self.liftRatio = liftRatio
        self.stretchX = stretchX
        self.stretchY = stretchY
        self.tiltDegrees = tiltDegrees
        self.shadowScale = shadowScale
        self.shadowOpacity = shadowOpacity
    }

    /// 味付けなし。**Reduce Motion のときはこれを使う**（プラン §7.5）。
    public static let still = Flourish()
}

/// 姿勢ごとの味付けを、区切りの中の経過秒から求める。
public enum ProceduralMotion {

    // MARK: - 歩く

    /// 弾みの周期（秒）。歩行 4 コマを 8fps で回すと 1 周 0.5 秒なので、
    /// その半分にして 1 歩ごとに 1 回弾ませる。
    public static let walkBouncePeriodSeconds: Double = 0.25
    /// 弾む高さ（身長に対する比）。身長 180pt なら約 3pt（プラン §5.5 の「2〜3pt」）。
    public static let walkLiftRatio: Double = 0.017
    /// 着地した瞬間のつぶれ。
    public static let walkSquash: Double = 0.035

    // MARK: - 呼吸

    /// 立っているときの呼吸の周期と深さ。
    public static let breathPeriodSeconds: Double = 3.4
    public static let breathAmount: Double = 0.02
    /// 眠っているときはゆっくり深く。
    public static let sleepBreathPeriodSeconds: Double = 5.2
    public static let sleepBreathAmount: Double = 0.032

    // MARK: - 首のかしげ

    /// すわっているとき、ときどき首をかしげる周期と角度。
    public static let tiltPeriodSeconds: Double = 7.0
    public static let sitTiltDegrees: Double = 4.0
    /// 見上げているときは、もう少し小さく。
    public static let lookTiltDegrees: Double = 2.5

    // MARK: - 跳ねる

    /// よろこぶ・踊るときの跳ねの周期と高さ。
    public static let hopPeriodSeconds: Double = 0.62
    public static let hopLiftRatio: Double = 0.055
    /// 左右の揺れ。跳ねの 2 倍の周期にすると、右へ跳んで左へ跳ぶ形になる。
    public static let swayDegrees: Double = 5.0
    /// 浮いたときに影が縮む量と、薄くなる量。
    public static let hopShadowShrink: Double = 0.34
    public static let hopShadowFade: Double = 0.40

    /// その瞬間の味付け。`localSeconds` は区切りが始まってからの秒数。
    public static func flourish(pose: Pose, localSeconds: Double) -> Flourish {
        switch pose {
        case .walk:      walking(localSeconds)
        case .happy:     hopping(localSeconds)
        case .sleep:     breathing(localSeconds, period: sleepBreathPeriodSeconds,
                                   amount: sleepBreathAmount)
        case .sit:       breathing(localSeconds, tiltDegrees: sitTiltDegrees)
        case .lookUp:    breathing(localSeconds, tiltDegrees: lookTiltDegrees)
        case .idle, .surprised: breathing(localSeconds)
        }
    }

    /// 歩く。1 歩ごとに浮いて、着地でつぶれる。
    static func walking(_ seconds: Double) -> Flourish {
        let height = abs(sin(.pi * seconds / walkBouncePeriodSeconds))
        let contact = 1 - height                       // 0 が空中、1 が接地
        return Flourish(liftRatio: height * walkLiftRatio,
                        stretchX: 1 + walkSquash * contact * 0.6,
                        stretchY: 1 - walkSquash * contact,
                        shadowScale: 1 - height * hopShadowShrink * 0.5,
                        shadowOpacity: 1 - height * hopShadowFade * 0.5)
    }

    /// よろこぶ・踊る。小さく跳ねながら左右に揺れる。
    static func hopping(_ seconds: Double) -> Flourish {
        let height = abs(sin(.pi * seconds / hopPeriodSeconds))
        let sway = sin(2 * .pi * seconds / (hopPeriodSeconds * 2))
        return Flourish(liftRatio: height * hopLiftRatio,
                        stretchX: 1 - walkSquash * height * 0.5,
                        stretchY: 1 + walkSquash * height,
                        tiltDegrees: swayDegrees * sway,
                        shadowScale: 1 - height * hopShadowShrink,
                        shadowOpacity: 1 - height * hopShadowFade)
    }

    /// 呼吸。体積を保つように、縦に伸びたら横は少し縮める。
    static func breathing(_ seconds: Double,
                          period: Double = breathPeriodSeconds,
                          amount: Double = breathAmount,
                          tiltDegrees: Double = 0) -> Flourish {
        let breath = sin(2 * .pi * seconds / period)
        let tilt = tiltDegrees == 0 ? 0 : tiltDegrees * sin(2 * .pi * seconds / tiltPeriodSeconds)
        return Flourish(stretchX: 1 - amount * 0.5 * breath,
                        stretchY: 1 + amount * breath,
                        tiltDegrees: tilt)
    }
}
