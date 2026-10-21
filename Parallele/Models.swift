import Foundation

enum ImageSide: String, Codable, CaseIterable, Identifiable {
    case before, after

    var id: String { rawValue }
    var title: String { self == .before ? "Avant" : "Après" }
}

enum ComparisonMode: String, Codable, CaseIterable, Identifiable {
    case automatic, swipe, sideBySide

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Adaptatif"
        case .swipe: "Balayage"
        case .sideBySide: "Côte à côte"
        }
    }

    var systemImage: String {
        switch self {
        case .automatic: "rectangle.2.swap"
        case .swipe: "slider.horizontal.below.rectangle"
        case .sideBySide: "rectangle.split.2x1"
        }
    }
}

struct ImageAnnotation: Identifiable, Codable, Equatable {
    var id: UUID
    var x: Double
    var y: Double
    var text: String
    var side: ImageSide

    init(
        id: UUID = UUID(),
        x: Double,
        y: Double,
        text: String,
        side: ImageSide
    ) {
        self.id = id
        self.x = x
        self.y = y
        self.text = text
        self.side = side
    }
}

struct ComparisonProject: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    var beforeFilename: String
    var afterFilename: String
    var annotations: [ImageAnnotation]
    var split: Double
    var mode: ComparisonMode
    var zoom: Double
    var panX: Double? = nil
    var panY: Double? = nil

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        beforeFilename: String,
        afterFilename: String,
        annotations: [ImageAnnotation] = [],
        split: Double = 0.5,
        mode: ComparisonMode = .automatic,
        zoom: Double = 1
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.beforeFilename = beforeFilename
        self.afterFilename = afterFilename
        self.annotations = annotations
        self.split = split
        self.mode = mode
        self.zoom = zoom
    }
}
