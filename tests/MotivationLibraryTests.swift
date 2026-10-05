import Foundation

// Executed by swiftc on the macOS runner before the iPhone build.
@main
struct MotivationLibraryTests {
    static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        if !condition() { throw NSError(domain: "MotivationTests", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    static func rejects(_ message: String, _ action: () throws -> Void) throws {
        var failed = false
        do { try action() } catch { failed = true }
        try require(failed, message)
    }
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("motivation-tests-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: root) }
        let library = try MotivationLibrary(directory: root)
        try require(library.cards == MotivationCard.originals, "Initial original wall missing")
        let photo = Data([0x01, 0x02, 0x03]) // Image encoding is tested by the native import path, not Foundation.
        let custom = MotivationCard(id: "custom", title: "  我的目标  ", subtitle: "  每周进步  ")
        try library.save(custom, jpeg: photo)
        let saved = library.cards.last!
        try require(saved.title == "我的目标" && saved.subtitle == "每周进步", "Whitespace cleanup failed")
        let firstURL = library.imageURL(for: saved)!
        let firstData = try Data(contentsOf: firstURL)
        try require(firstData == photo, "Private image copy missing")
        let restarted = try MotivationLibrary(directory: root)
        try require(restarted.cards == library.cards, "Restart lost card or order")
        var edited = saved
        edited.title = "改后的目标"
        try restarted.save(edited, jpeg: nil)
        try require(restarted.cards.last?.imageFile == saved.imageFile, "Text edit changed image")
        try require(fm.fileExists(atPath: firstURL.path), "Text edit deleted image")
        try restarted.save(edited, jpeg: Data([0x04, 0x05]))
        let replaced = restarted.cards.last!
        try require(replaced.imageFile != saved.imageFile && !fm.fileExists(atPath: firstURL.path), "Image replacement left old image")
        let reversed = restarted.cards.reversed().map(\.id)
        try restarted.reorder(ids: reversed)
        let reordered = try MotivationLibrary(directory: root)
        try require(reordered.cards.map(\.id) == reversed, "Order did not survive restart")
        let before = restarted.cards
        try rejects("Duplicate reorder accepted") { try restarted.reorder(ids: Array(repeating: "custom", count: before.count)) }
        try rejects("Missing reorder ID accepted") { try restarted.reorder(ids: ["custom"]) }
        try rejects("Empty title accepted") { try restarted.save(.init(id: "empty", title: "  ", subtitle: ""), jpeg: photo) }
        try rejects("No image accepted") { try restarted.save(.init(id: "no-image", title: "目标", subtitle: ""), jpeg: nil) }
        try rejects("Unsafe image path accepted") { try restarted.save(.init(id: "unsafe", title: "目标", subtitle: "", imageFile: "../outside.jpg"), jpeg: nil) }
        try rejects("Too long title accepted") { try restarted.save(.init(id: "long", title: String(repeating: "字", count: 81), subtitle: ""), jpeg: photo) }
        try require(restarted.cards == before, "Rejected change mutated wall")
        let replacementURL = restarted.imageURL(for: replaced)!
        try restarted.delete(id: "custom")
        try require(!fm.fileExists(atPath: replacementURL.path), "Delete retained private image")
        for card in restarted.cards { try restarted.delete(id: card.id) }
        let emptied = try MotivationLibrary(directory: root)
        try require(emptied.cards.isEmpty, "Deleted defaults were restored after restart")
        print("PASS: add, private copy, text edit, replace, reorder, validation, delete, empty wall, restart")

        // A metadata write failure must keep the previous in-memory wall and remove new photos.
        let blocked = root.appendingPathComponent("blocked", isDirectory: true)
        let failing = try MotivationLibrary(directory: blocked)
        try fm.createDirectory(at: blocked.appendingPathComponent("wall.json"), withIntermediateDirectories: true)
        try rejects("Failed write unexpectedly succeeded") { try failing.save(custom, jpeg: photo) }
        try require(failing.cards == MotivationCard.originals, "Failed write changed visible cards")
        let files = try fm.contentsOfDirectory(atPath: blocked.path)
        try require(files == ["wall.json"], "Failed save leaked an image")
        print("PASS: failed metadata save rolls back new image and visible wall")

        let damaged = root.appendingPathComponent("damaged", isDirectory: true)
        try fm.createDirectory(at: damaged, withIntermediateDirectories: true)
        let badURL = damaged.appendingPathComponent("wall.json")
        let badData = Data("not valid JSON".utf8)
        try badData.write(to: badURL)
        try rejects("Corrupt metadata accepted") { _ = try MotivationLibrary(directory: damaged) }
        let preserved = try Data(contentsOf: badURL)
        try require(preserved == badData, "Corrupt metadata was overwritten")
        print("PASS: corrupt metadata preserved for recovery")
    }
}
