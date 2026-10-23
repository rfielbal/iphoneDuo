import Foundation
import Observation
import UIKit

enum ProjectStoreError: LocalizedError {
    case unreadableLibrary
    case missingProject
    case invalidImage
    case invalidFilename
    case missingImage

    var errorDescription: String? {
        switch self {
        case .unreadableLibrary:
            "La bibliothèque n’a pas pu être lue. Vos fichiers sont conservés. Relancez l’application ou restaurez le fichier projects.json avant de modifier la bibliothèque."
        case .missingProject:
            "Cette comparaison n’existe plus dans la bibliothèque."
        case .invalidImage:
            "Cette image ne peut pas être importée. Choisissez une autre photo."
        case .invalidFilename:
            "Le nom d’un fichier de la comparaison n’est pas valide."
        case .missingImage:
            "Une image de cette comparaison est introuvable."
        }
    }
}

@MainActor
@Observable
final class ProjectStore {
    private(set) var projects: [ComparisonProject] = []
    var errorMessage: String?

    @ObservationIgnored private let directory: URL
    @ObservationIgnored private let imageDirectory: URL
    @ObservationIgnored private let manifestURL: URL
    @ObservationIgnored private let fileManager = FileManager.default
    @ObservationIgnored private var loadFailed = false
    @ObservationIgnored private var imageCache = NSCache<NSString, UIImage>()

    /// `seedDemo: false` is useful for an empty library in previews and tests.
    init(directory: URL? = nil, seedDemo: Bool = true) {
        let root = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("Parallele", isDirectory: true)
        self.directory = root
        imageDirectory = root.appendingPathComponent("Images", isDirectory: true)
        manifestURL = root.appendingPathComponent("projects.json")
        imageCache.totalCostLimit = 100 * 1024 * 1024

        do {
            try fileManager.createDirectory(at: imageDirectory, withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: manifestURL.path) {
                let decoded = try JSONDecoder().decode(
                    [ComparisonProject].self,
                    from: Data(contentsOf: manifestURL)
                )
                guard Set(decoded.map(\.id)).count == decoded.count else {
                    throw ProjectStoreError.unreadableLibrary
                }
                for project in decoded {
                    try validateFilename(project.beforeFilename)
                    try validateFilename(project.afterFilename)
                }
                projects = decoded.sorted { $0.updatedAt > $1.updatedAt }
            } else if seedDemo,
                      let before = Self.demoImage(named: "DemoBefore"),
                      let after = Self.demoImage(named: "DemoAfter") {
                _ = try create(title: "Une autre lumière", before: before, after: after)
            } else {
                // A saved empty manifest prevents demo content from reappearing
                // after the user intentionally empties the library.
                try persist([])
            }
        } catch {
            loadFailed = true
            errorMessage = "Impossible d’ouvrir la bibliothèque. Aucun fichier n’a été remplacé. \(error.localizedDescription)"
        }
    }

    func project(id: UUID) -> ComparisonProject? {
        projects.first { $0.id == id }
    }

    func image(for project: ComparisonProject, side: ImageSide) -> UIImage? {
        let filename = side == .before ? project.beforeFilename : project.afterFilename
        guard (try? validateFilename(filename)) != nil else { return nil }
        if let image = imageCache.object(forKey: filename as NSString) {
            return image
        }
        let url = imageDirectory.appendingPathComponent(filename)
        guard let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache(image, filename: filename)
        return image
    }

    @discardableResult
    func create(title: String, before: UIImage, after: UIImage) throws -> UUID {
        try requireWritableLibrary()
        let id = UUID()
        let beforeFilename = "\(id.uuidString.lowercased())-before.jpg"
        let afterFilename = "\(id.uuidString.lowercased())-after.jpg"
        let normalizedBefore = try normalizedImage(before)
        let normalizedAfter = try normalizedImage(after)
        guard let beforeData = normalizedBefore.jpegData(compressionQuality: 0.94),
              let afterData = normalizedAfter.jpegData(compressionQuality: 0.94) else {
            throw ProjectStoreError.invalidImage
        }
        let beforeURL = imageDirectory.appendingPathComponent(beforeFilename)
        let afterURL = imageDirectory.appendingPathComponent(afterFilename)
        do {
            try beforeData.write(to: beforeURL, options: .atomic)
            try afterData.write(to: afterURL, options: .atomic)
            let item = ComparisonProject(
                id: id,
                title: Self.cleanTitle(title),
                beforeFilename: beforeFilename,
                afterFilename: afterFilename
            )
            let next = [item] + projects
            try persist(next)
            projects = next
            cache(normalizedBefore, filename: beforeFilename)
            cache(normalizedAfter, filename: afterFilename)
            return id
        } catch {
            // Only freshly generated filenames are removed on a failed save.
            try? fileManager.removeItem(at: beforeURL)
            try? fileManager.removeItem(at: afterURL)
            throw error
        }
    }

    func update(_ project: ComparisonProject) throws {
        try requireWritableLibrary()
        guard let index = projects.firstIndex(where: { $0.id == project.id }) else {
            throw ProjectStoreError.missingProject
        }
        try validateFilename(project.beforeFilename)
        try validateFilename(project.afterFilename)
        var updated = project
        updated.title = Self.cleanTitle(project.title)
        updated.createdAt = projects[index].createdAt
        updated.updatedAt = .now
        updated.split = Self.clamped(project.split, lower: 0, upper: 1, fallback: 0.5)
        updated.zoom = Self.clamped(project.zoom, lower: 1, upper: 4, fallback: 1)
        let panLimit = (updated.zoom - 1) / 2
        updated.panX = Self.clamped(project.panX ?? 0, lower: -panLimit, upper: panLimit, fallback: 0)
        updated.panY = Self.clamped(project.panY ?? 0, lower: -panLimit, upper: panLimit, fallback: 0)
        updated.annotations = project.annotations.map {
            var annotation = $0
            annotation.x = Self.clamped($0.x, lower: 0, upper: 1, fallback: 0.5)
            annotation.y = Self.clamped($0.y, lower: 0, upper: 1, fallback: 0.5)
            return annotation
        }
        var next = projects
        next[index] = updated
        next.sort { $0.updatedAt > $1.updatedAt }
        try persist(next)
        projects = next
    }

    func delete(id: UUID) throws {
        try requireWritableLibrary()
        guard let item = project(id: id) else { throw ProjectStoreError.missingProject }
        let next = projects.filter { $0.id != id }
        try persist(next)
        projects = next

        // The manifest is committed first. A cleanup failure can leave an orphan
        // image, but can never leave a saved comparison without its own images.
        let stillUsed = Set(next.flatMap { [$0.beforeFilename, $0.afterFilename] })
        for filename in [item.beforeFilename, item.afterFilename] where !stillUsed.contains(filename) {
            guard (try? validateFilename(filename)) != nil else { continue }
            imageCache.removeObject(forKey: filename as NSString)
            try? fileManager.removeItem(at: imageDirectory.appendingPathComponent(filename))
        }
    }

    @discardableResult
    func duplicate(id: UUID) throws -> UUID {
        try requireWritableLibrary()
        guard let original = project(id: id) else { throw ProjectStoreError.missingProject }
        guard let before = image(for: original, side: .before),
              let after = image(for: original, side: .after) else {
            throw ProjectStoreError.missingImage
        }
        let newID = try create(title: "\(original.title) — copie", before: before, after: after)
        guard var copy = project(id: newID) else { throw ProjectStoreError.missingProject }
        copy.annotations = original.annotations.map {
            ImageAnnotation(x: $0.x, y: $0.y, text: $0.text, side: $0.side, status: $0.status)
        }
        copy.split = original.split
        copy.mode = original.mode
        copy.zoom = original.zoom
        copy.panX = original.panX
        copy.panY = original.panY
        do {
            try update(copy)
            return newID
        } catch {
            try? delete(id: newID)
            throw error
        }
    }

    private func persist(_ items: [ComparisonProject]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(items)
        try data.write(to: manifestURL, options: .atomic)
    }

    private func requireWritableLibrary() throws {
        if loadFailed { throw ProjectStoreError.unreadableLibrary }
    }

    private func validateFilename(_ filename: String) throws {
        guard !filename.isEmpty,
              filename == URL(fileURLWithPath: filename).lastPathComponent,
              !filename.contains(".."),
              !filename.contains("/"),
              !filename.contains("\\"),
              filename.lowercased().hasSuffix(".jpg") else {
            throw ProjectStoreError.invalidFilename
        }
        let target = imageDirectory.appendingPathComponent(filename)
        if let values = try? target.resourceValues(forKeys: [.isSymbolicLinkKey]),
           values.isSymbolicLink == true {
            throw ProjectStoreError.invalidFilename
        }
    }

    private func normalizedImage(_ image: UIImage) throws -> UIImage {
        guard image.size.width.isFinite, image.size.height.isFinite,
              image.size.width > 0, image.size.height > 0 else {
            throw ProjectStoreError.invalidImage
        }
        let longest = max(image.size.width * image.scale, image.size.height * image.scale)
        let pixelRatio = min(1, 2500 / longest)
        let target = CGSize(
            width: max(1, (image.size.width * image.scale * pixelRatio).rounded()),
            height: max(1, (image.size.height * image.scale * pixelRatio).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            UIColor.white.setFill()
            UIRectFill(CGRect(origin: .zero, size: target))
            // UIKit applies imageOrientation here, including camera EXIF rotation.
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private func cache(_ image: UIImage, filename: String) {
        let width = image.cgImage?.width ?? Int(image.size.width * image.scale)
        let height = image.cgImage?.height ?? Int(image.size.height * image.scale)
        imageCache.setObject(image, forKey: filename as NSString, cost: width * height * 4)
    }

    private static func demoImage(named name: String) -> UIImage? {
        if let url = Bundle.main.url(forResource: name, withExtension: "jpg") {
            return UIImage(contentsOfFile: url.path)
        }
        return UIImage(named: name)
    }

    private static func cleanTitle(_ title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Sans titre" : String(trimmed.prefix(160))
    }

    private static func clamped(_ value: Double, lower: Double, upper: Double, fallback: Double) -> Double {
        value.isFinite ? min(upper, max(lower, value)) : fallback
    }
}
