import SwiftUI
import UIKit
import Combine
import ImageIO
import UniformTypeIdentifiers

@MainActor
final class MotivationStore: ObservableObject {
    @Published private(set) var cards: [MotivationCard] = []
    @Published private(set) var loadError: String?
    private var library: MotivationLibrary?
    private let imageCache = NSCache<NSString, UIImage>()
    var canEdit: Bool { library != nil }

    init() {
        imageCache.totalCostLimit = 64 * 1024 * 1024
        imageCache.countLimit = 12
        do {
            let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            library = try MotivationLibrary(directory: base.appendingPathComponent("MotivationWall", isDirectory: true))
            cards = library?.cards ?? []
        } catch {
            cards = MotivationCard.originals
            loadError = "动机墙记录无法读取，编辑已暂停以保护现有数据。\n\(error.localizedDescription)"
        }
    }
    func image(for card: MotivationCard) -> UIImage? {
        if let url = library?.imageURL(for: card) {
            let key = url.lastPathComponent as NSString
            if let cached = imageCache.object(forKey: key) { return cached }
            if let image = UIImage(contentsOfFile: url.path) {
                let cost = (image.cgImage?.width ?? 0) * (image.cgImage?.height ?? 0) * 4
                imageCache.setObject(image, forKey: key, cost: cost)
                return image
            }
        }
        if let name = card.assetName { return UIImage(named: name) }
        return nil
    }
    func save(_ card: MotivationCard, jpeg: Data?) throws {
        guard let library else { throw MotivationError.invalidCard }
        try library.save(card, jpeg: jpeg)
        imageCache.removeAllObjects()
        cards = library.cards
    }
    func delete(_ card: MotivationCard) throws {
        guard let library else { throw MotivationError.invalidCard }
        try library.delete(id: card.id)
        imageCache.removeAllObjects()
        cards = library.cards
    }
    func move(from offsets: IndexSet, to destination: Int) throws {
        guard let library else { throw MotivationError.invalidOrder }
        var updated = cards
        updated.move(fromOffsets: offsets, toOffset: destination)
        try library.reorder(ids: updated.map(\.id))
        cards = library.cards
    }

    // Run off the main actor. Applies EXIF rotation and bounds image dimensions
    // before saving a private copy, so deleting the source photo is harmless.
    nonisolated static func preparePhoto(_ data: Data) throws -> Data {
        guard data.count <= 25 * 1024 * 1024 else { throw MotivationError.oversizedImage }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1800
              ] as CFDictionary) else { throw MotivationError.invalidImage }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result as CFMutableData, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw MotivationError.invalidImage
        }
        CGImageDestinationAddImage(destination, cg, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw MotivationError.invalidImage }
        return Data(referencing: result)
    }
}
