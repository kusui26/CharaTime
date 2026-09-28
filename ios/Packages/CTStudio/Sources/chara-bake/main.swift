import Foundation
import CharaBake

// 既定の 5 体を焼く Mac の道具（プラン §6.4 の ①、§9 Phase 2 の 2-C ⑦）。中身は CharaBake にある。
let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
exit(await CharaBakeMain.run(Array(CommandLine.arguments.dropFirst()), currentDirectory: directory))
