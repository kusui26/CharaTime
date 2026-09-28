import Foundation
import CTStudio

/// chara-bake の本体（入口の `main.swift` から呼ぶ）。終了コード: 0 = できた、1 = そろわなかった・失敗した、2 = 引数の誤り。
public enum CharaBakeMain {

    public static func run(_ arguments: [String], currentDirectory: URL) async -> Int32 {
        do {
            let command = try BakeCommand.parse(arguments)
            let folder = { (path: String) in
                URL(fileURLWithPath: path, isDirectory: true, relativeTo: currentDirectory)
                    .standardizedFileURL
            }
            let root = command.root.map(folder) ?? currentDirectory.standardizedFileURL
            let repository = Repository(root: root, output: command.output.map(folder))
            return try await perform(command, repository: repository, currentDirectory: currentDirectory)
        } catch {
            FileHandle.standardError.write(Data("✗ \(error)\n".utf8))
            guard case .usage = error else { return 1 }
            FileHandle.standardError.write(Data((BakeCommand.usage + "\n").utf8))
            return 2
        }
    }

    static func perform(_ command: BakeCommand, repository: Repository,
                        currentDirectory: URL) async throws(BakeError) -> Int32 {
        switch command.action {
        case .help:
            print(BakeCommand.usage)
            return 0
        case .bake(let id, let files):
            return try await bake(id, files: files, command: command, repository: repository,
                                  currentDirectory: currentDirectory)
        case .sample(let id, let folder):
            let target = URL(fileURLWithPath: folder, isDirectory: true, relativeTo: currentDirectory)
            let written = try SampleSheets.write(id, repository: repository, to: target, scale: command.scale)
            written.forEach { print("✓ \($0.path(percentEncoded: false))") }
            return 0
        case .contactSheet:
            let catalog = try repository.bundledCatalog()
            let sheet = CatalogSheet.render(try CatalogSheet.rows(repository, catalog: catalog),
                                            groundRatio: catalog.spriteGeometry.groundRatio)
            let url = try ContactSheet.write(sheet, to: repository.shots.appending(path: "contact-sheet.png"))
            print("✓ \(BakeSummary.relative(url, to: repository.root))")
            return 0
        }
    }

    static func bake(_ id: String, files: [String], command: BakeCommand, repository: Repository,
                     currentDirectory: URL) async throws(BakeError) -> Int32 {
        // raw/ を探す前に、同梱のキャラの id かを確かめる（打ち間違いを「絵が無い」と取り違えさせない）。
        _ = try repository.bundledCatalog().character(id)
        let urls = files.isEmpty ? RawNaming.images(in: repository.rawFolder(of: id))
            : files.map { URL(fileURLWithPath: $0, relativeTo: currentDirectory).standardizedFileURL }
        guard !urls.isEmpty else {
            throw .noRawImages(BakeSummary.relative(repository.rawFolder(of: id), to: repository.root))
        }
        let baker = CharacterBake(repository: repository, service: command.service,
                                  lifter: VisionSubjectLifter())
        let outcome = try await baker.bake(id, files: urls)
        print(BakeSummary.text(outcome, root: repository.root))
        return outcome.final == nil ? 1 : 0
    }
}
