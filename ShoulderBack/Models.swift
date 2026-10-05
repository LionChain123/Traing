import Foundation
import Combine

struct Exercise: Codable, Identifiable {
    let id: String
    let name: String
    let detail: String
    let prescription: String
    let setKeys: [String]
    let optionalKeys: [String]
}

struct TrainingDay: Codable, Identifiable {
    let id: Int
    let name: String
    let focus: String
    let kind: String
    let note: String
    let exercises: [Exercise]
    var isStrength: Bool { kind == "力量" }
    var requiredKeys: [String] { exercises.flatMap { e in e.setKeys.filter { !e.optionalKeys.contains($0) } } }
    var allKeys: [String] { exercises.flatMap(\.setKeys) }
}

struct Principle: Codable, Identifiable {
    let title: String
    let body: String
    var id: String { title }
}

struct Plan: Codable {
    let days: [TrainingDay]
    let principles: [Principle]
    static let bundled: Plan = {
        guard let url = Bundle.main.url(forResource: "Plan", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let plan = try? JSONDecoder().decode(Plan.self, from: data),
              !plan.days.isEmpty else { fatalError("Missing or invalid bundled Plan.json") }
        return plan
    }()
}

struct SetEntry: Codable {
    var done = false
    var weight = ""
    var reps = ""
}

struct WeekRecord: Codable, Identifiable {
    let id: String
    var entries: [String: SetEntry] = [:]
}

@MainActor
final class TrainingStore: ObservableObject {
    let plan = Plan.bundled
    @Published private(set) var records: [String: WeekRecord] = [:]
    @Published private(set) var persistenceError: String?
    private var unreadableData: Data?
    private let storageKey = "shoulder-back-native-v1"
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        return calendar
    }
    static func weekID(_ date: Date = Date()) -> String {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)!.start
        let parts = calendar.dateComponents([.year, .month, .day], from: start)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
    var currentWeek: String { Self.weekID() }
    var today: TrainingDay {
        let weekday = Calendar.current.component(.weekday, from: Date()) - 1
        return plan.days.first { $0.id == weekday } ?? plan.days[0]
    }
    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey) {
            do { records = try JSONDecoder().decode([String: WeekRecord].self, from: data) }
            catch {
                unreadableData = data
                persistenceError = "保存的记录无法读取，已暂停写入以保护原数据。请导出原始备份以便恢复。"
            }
        }
    }
    func entry(_ key: String, week: String) -> SetEntry {
        records[week]?.entries[key] ?? SetEntry()
    }
    func update(_ key: String, week: String, _ change: (inout SetEntry) -> Void) {
        guard persistenceError == nil else { return }
        var record = records[week] ?? WeekRecord(id: week)
        var item = record.entries[key] ?? SetEntry()
        change(&item)
        record.entries[key] = item
        records[week] = record
        save()
    }
    func completed(_ keys: [String], week: String) -> Int {
        keys.filter { entry($0, week: week).done }.count
    }
    var requiredKeys: [String] { plan.days.flatMap(\.requiredKeys) }
    func progress(week: String) -> Double {
        Double(completed(requiredKeys, week: week)) / Double(max(requiredKeys.count, 1))
    }
    func resetCurrentWeek() {
        guard persistenceError == nil else { return }
        records.removeValue(forKey: currentWeek)
        save()
    }
    private func save() {
        do { UserDefaults.standard.set(try JSONEncoder().encode(records), forKey: storageKey) }
        catch { persistenceError = "记录保存失败，请导出备份。" }
    }
    var exportText: String {
        if let data = unreadableData {
            if let text = String(data: data, encoding: .utf8) { return text }
            return "SHOULDER_BACK_RAW_BASE64\n" + data.base64EncodedString()
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return (try? encoder.encode(records)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }
}
