"""接続中の iOS 端末を 1 台調べて、タブ区切りで返す。

devicectl の表形式の出力を列で切ると、端末名や機種名に空白が入った時点で
ずれる（「kensuke の iPhone」「iPhone 17 Pro (iPhone18,1)」など）。
JSON で受けて確実に取り出す。

出力: UDID<TAB>名前<TAB>機種<TAB>デベロッパモードの状態<TAB>OS の版
端末が無ければ何も出力せず、終了コード 1 を返す。

**OS の版まで返すのは、この計画では版が判定の前提条件だから。**
ウィジェット疑似アニメのスパイクは「Xcode 26.1 以降の SDK × iOS 26.1 以降」で
測ることに意味があり（プラン D-15）、実機が iOS 27 に上がると Xcode 26.6 からは
そもそも入らなくなる（R-6）。入れる前に読めるようにしておく。
"""

import json
import sys


def main() -> int:
    if len(sys.argv) < 2:
        return 1
    try:
        with open(sys.argv[1], encoding="utf-8") as handle:
            payload = json.load(handle)
    except (OSError, json.JSONDecodeError):
        return 1

    devices = payload.get("result", {}).get("devices", [])
    for device in devices:
        properties = device.get("deviceProperties", {})
        hardware = device.get("hardwareProperties", {})
        fields = [
            device.get("identifier", ""),
            properties.get("name", ""),
            hardware.get("marketingName", ""),
            properties.get("developerModeStatus", "unknown"),
            properties.get("osVersionNumber", "unknown"),
        ]
        print("\t".join(fields))
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
