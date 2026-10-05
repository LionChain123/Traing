import Foundation

struct MotivationCard: Codable, Identifiable, Equatable {
    let id: String
    var title: String
    var subtitle: String
    var assetName: String?
    var imageFile: String?

    static let originals: [MotivationCard] = [
        .init(id: "original-1", title: "肩背要撑起来", subtitle: "宽肩、背阔、核心线条", assetName: "Motivation1"),
        .init(id: "original-2", title: "力量感来自长期积累", subtitle: "每一周都比上一周更强一点", assetName: "Motivation2"),
        .init(id: "original-3", title: "体型也是气质的一部分", subtitle: "训练、饮食、恢复缺一不可", assetName: "Motivation3"),
        .init(id: "original-4", title: "保持低体脂和清晰线条", subtitle: "力量训练负责塑形，有氧负责辅助", assetName: "Motivation4")
    ]
}

enum MotivationError: LocalizedError {
    case invalidCard, invalidOrder, invalidImage, oversizedImage
    var errorDescription: String? {
        switch self {
        case .invalidCard: return "请填写 1–80 字标题、最多 240 字说明，并选择图片。"
        case .invalidOrder: return "动机墙顺序保存失败，请重新打开页面。"
        case .invalidImage: return "无法读取这张图片，请选择另一张照片。"
        case .oversizedImage: return "这张图片超过 25 MB，请选择较小的图片。"
        }
    }
}

// Image files and metadata share the app container. Atomic metadata writes
// preserve the previous wall if a save fails; no training data is touched.
final class MotivationLibrary {
    private(set) var cards: [MotivationCard]
    let directory: URL
    private var metadataURL: URL { directory.appendingPathComponent("wall.json") }
    init(directory: URL) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("wall.json")
        if FileManager.default.fileExists(atPath: url.path) {
            let loaded = try JSONDecoder().decode([MotivationCard].self, from: Data(contentsOf: url))
            try Self.validate(loaded)
            cards = loaded
        } else {
            cards = MotivationCard.originals
        }
    }
    func imageURL(for card: MotivationCard) -> URL? {
        guard let name = card.imageFile, Self.isSafeFilename(name) else { return nil }
        return directory.appendingPathComponent(name)
    }
    func save(_ draft: MotivationCard, jpeg: Data?) throws {
        var card = draft
        card.title = card.title.trimmingCharacters(in: .whitespacesAndNewlines)
        card.subtitle = card.subtitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let previous = cards.first { $0.id == card.id }
        var newURL: URL?
        if let jpeg {
            guard !jpeg.isEmpty else { throw MotivationError.invalidImage }
            let name = UUID().uuidString + ".jpg"
            card.imageFile = name
            card.assetName = nil
            newURL = directory.appendingPathComponent(name)
        }
        var updated = cards
        if let index = updated.firstIndex(where: { $0.id == card.id }) { updated[index] = card }
        else { updated.append(card) }
        try Self.validate(updated)
        if let jpeg, let newURL { try jpeg.write(to: newURL, options: .atomic) }
        do { try persist(updated) }
        catch {
            if let newURL { try? FileManager.default.removeItem(at: newURL) }
            throw error
        }
        if let previous, previous.imageFile != card.imageFile,
           let oldURL = imageURL(for: previous) { try? FileManager.default.removeItem(at: oldURL) }
    }
    func delete(id: String) throws {
        guard let card = cards.first(where: { $0.id == id }) else { return }
        try persist(cards.filter { $0.id != id })
        if let url = imageURL(for: card) { try? FileManager.default.removeItem(at: url) }
    }
    func reorder(ids: [String]) throws {
        guard ids.count == cards.count, Set(ids).count == ids.count,
              Set(ids) == Set(cards.map(\.id)) else { throw MotivationError.invalidOrder }
        let byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        try persist(ids.compactMap { byID[$0] })
    }
    private func persist(_ updated: [MotivationCard]) throws {
        try Self.validate(updated)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(updated).write(to: metadataURL, options: .atomic)
        cards = updated
    }
    private static func isSafeFilename(_ name: String) -> Bool {
        !name.isEmpty && name == (name as NSString).lastPathComponent && !name.contains("..") && !name.contains("\\")
    }
    private static func validate(_ cards: [MotivationCard]) throws {
        guard Set(cards.map(\.id)).count == cards.count else { throw MotivationError.invalidCard }
        for card in cards {
            guard !card.id.isEmpty, !card.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  card.title.count <= 80, card.subtitle.count <= 240,
                  card.assetName != nil || card.imageFile != nil else { throw MotivationError.invalidCard }
            if let file = card.imageFile, !isSafeFilename(file) { throw MotivationError.invalidCard }
        }
    }
}
