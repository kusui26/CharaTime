import Testing
import Foundation
@testable import CTAssets
import CTCore

/// パイプラインが焼いた書体の一覧と、動かし方が使う書体の一族が食い違っていないか（プラン 3-2b）。
///
/// 一族（CTCore の `MaskFontFamily`）は Swift の側、書体を焼くのは Python の側（tools/pipeline/masks.py）。
/// 2 か所に同じ一覧があるので、`mask_fonts.json` を仲立ちにして、ここで突き合わせる。
@Suite("マスク書体の一覧")
struct MaskFontCatalogTests {

    @Test("書体の一覧は、動かし方が使う一族と同じ並び")
    func catalogMatchesTheFamily() throws {
        let fonts = try Catalog.maskFonts()
        #expect(fonts.map { DigitSet($0.digits) } == MaskFontFamily.digitSets)
    }

    /// Swift の側は、集まりから `CTMask` ＋並び（`CTMask05`）で書体の名前を作る。同じ規則か。
    @Test("書体の名前は CTMask に数字の並びを付けたもの")
    func namesFollowTheDigits() throws {
        for font in try Catalog.maskFonts() {
            #expect(font.name == "CTMask" + DigitSet(font.digits).key)
        }
    }
}
