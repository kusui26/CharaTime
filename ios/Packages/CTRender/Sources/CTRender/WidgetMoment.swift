import Foundation
import CTCore
import CTStore

/// ウィジェットのエントリ 1 件ぶんの、絵の材料（プラン §9 Phase 3 の 3-C ②）。
public struct WidgetMoment: Sendable, Equatable {

    public let date: Date
    /// その時刻の姿。日課エンジンの答えそのもので、アプリを開けば同じ姿がいる（Gate 3）。
    public let state: SceneState
    /// 夜の配色で描くか。
    public let isNight: Bool
    /// 居場所のつながりの番号。遠くへ移ったエントリで次の番号になる。
    ///
    /// 番号が同じあいだは、エントリ切替でキャラを滑らせる。変わったら滑らせず、消えて現れる
    /// （幅の半分を超えて滑ると、飛んでいったように見える。3-C ④'）。
    public let leg: Int
    /// 疑似アニメのタイマーの起点。エントリの日付の 0 時（D-18）。
    public let anchor: Date
    /// 疑似アニメの動かし方（3-C ④）。描画の段が 1fps 以上のときに使う。
    public let cue: AmbientCue

    public init(date: Date, state: SceneState, isNight: Bool, leg: Int, anchor: Date, cue: AmbientCue) {
        self.date = date
        self.state = state
        self.isNight = isNight
        self.leg = leg
        self.anchor = anchor
        self.cue = cue
    }
}

public enum WidgetMoments {

    /// 滑らせてよい距離（ウィジェットの幅に対する比）。これを超えたら、消えて現れる（3-C ④'）。
    public static let slideLimitWidthRatio: Double = 0.5

    /// エントリの時刻ごとの材料。姿は同じ日の表を使い回して一度に求める。
    ///
    /// `layout` はそのウィジェットの置き方。遠くへ移ったかを、実際に動くポイントで決めるために使う。
    public static func make(at dates: [Date], input: WorldInput, settings: CTStore.Settings,
                            layout: SceneLayout) -> [WidgetMoment] {
        let states = SceneEngine.sceneStates(at: dates, input: input)
        let legs = self.legs(of: states.map(\.position), layout: layout)
        let blink = BlinkRhythm.digits(characterID: input.character.id, userSeed: input.userSeed)
        return zip(states, legs).map { state, leg in
            let night = settings.nightMode && NightMode.isNight(at: state.time, calendar: input.calendar)
            return WidgetMoment(date: state.time, state: state, isNight: night, leg: leg,
                                anchor: input.calendar.startOfDay(for: state.time),
                                cue: AmbientCue.cue(for: state, room: input.room, blink: blink,
                                                    art: input.character.ambientArt))
        }
    }

    /// 居場所のつながりの番号。最初は 0 で、遠くへ移るたびに 1 つ進む。
    static func legs(of positions: [RoomPoint], layout: SceneLayout) -> [Int] {
        guard !positions.isEmpty else { return [] }
        let limit = layout.size.width * slideLimitWidthRatio
        let jumped = zip(positions, positions.dropFirst())
            .map { layout.horizontalTravel(from: $0, to: $1) > limit }
        return jumped.reduce(into: [0]) { legs, jump in
            legs.append((legs.last ?? 0) + (jump ? 1 : 0))
        }
    }
}

public extension WidgetMoment {

    /// 置く前の見本（ウィジェットのギャラリーと、読み込み中の仮の絵）。
    ///
    /// 昼の部屋の真ん中で、正面を向いて立つ。日課エンジンの答えではないので、見本にだけ使う。
    /// 見本は動かさないので、動かし方も立ち姿の 1 コマ目だけ（重ねるものは無い）。
    static func sample(room: Room, at date: Date, calendar: Calendar = .current) -> WidgetMoment {
        let state = SceneState(time: date, activity: .idle, position: room.floor.at(0.5, 0.6),
                               facing: .front, frame: 0)
        return WidgetMoment(date: date, state: state, isNight: false, leg: 0,
                            anchor: calendar.startOfDay(for: date),
                            cue: AmbientCue(pose: .idle, baseFrame: 0, overlays: []))
    }
}
