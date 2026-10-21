import XCTest
import UIKit
@testable import Parallele

final class ProjectStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("ParalleleTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let directory { try? FileManager.default.removeItem(at: directory) }
    }

    @MainActor
    func testRoundTripPreservesImagesAnnotationsAndPresentation() throws {
        let store = ProjectStore(directory: directory, seedDemo: false)
        let id = try store.create(title: "Lumière", before: image(.blue), after: image(.orange))
        var project = try XCTUnwrap(store.project(id: id))
        project.annotations = [
            ImageAnnotation(x: 0.23, y: 0.81, text: "Une ombre plus douce.", side: .before),
            ImageAnnotation(x: 0.67, y: 0.12, text: "Les hautes lumières.", side: .after)
        ]
        project.split = 0.73
        project.mode = .sideBySide
        project.zoom = 1.8
        project.panX = 0.31
        project.panY = -0.22
        try store.update(project)

        let reopened = ProjectStore(directory: directory, seedDemo: false)
        let loaded = try XCTUnwrap(reopened.project(id: id))
        XCTAssertEqual(loaded.annotations, project.annotations)
        XCTAssertEqual(loaded.split, 0.73)
        XCTAssertEqual(loaded.mode, .sideBySide)
        XCTAssertEqual(loaded.zoom, 1.8)
        XCTAssertEqual(loaded.panX, 0.31)
        XCTAssertEqual(loaded.panY, -0.22)
        XCTAssertNotNil(reopened.image(for: loaded, side: .before))
        XCTAssertNotNil(reopened.image(for: loaded, side: .after))
        XCTAssertNil(reopened.errorMessage)

        var reset = loaded
        reset.zoom = 1
        try reopened.update(reset)
        XCTAssertEqual(reopened.project(id: id)?.panX, 0)
        XCTAssertEqual(reopened.project(id: id)?.panY, 0)

        reset.zoom = 2
        reset.panX = 5
        reset.panY = .nan
        try reopened.update(reset)
        XCTAssertEqual(reopened.project(id: id)?.panX, 0.5)
        XCTAssertEqual(reopened.project(id: id)?.panY, 0)
    }

    @MainActor
    func testDeletionDoesNotRecreateDemoAndDoesNotDeleteUnrelatedFile() throws {
        let store = ProjectStore(directory: directory, seedDemo: false)
        let id = try store.create(title: "À supprimer", before: image(.red), after: image(.green))
        let project = try XCTUnwrap(store.project(id: id))
        let unrelated = directory.appendingPathComponent("MyNotes.txt")
        try Data("Keep me".utf8).write(to: unrelated)
        try store.delete(id: id)

        let reopened = ProjectStore(directory: directory)
        XCTAssertTrue(reopened.projects.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: unrelated.path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent("Images/\(project.beforeFilename)").path
        ))
    }

    @MainActor
    func testUnreadableManifestRemainsUntouchedAndRefusesWrites() throws {
        let manifest = directory.appendingPathComponent("projects.json")
        let malformed = Data("{not valid JSON".utf8)
        try malformed.write(to: manifest)
        let store = ProjectStore(directory: directory)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertThrowsError(try store.create(title: "Test", before: image(.black), after: image(.white)))
        XCTAssertEqual(try Data(contentsOf: manifest), malformed)
    }

    @MainActor
    func testDuplicatePreservesNotesWithoutSharingImagesOrAnnotationIDs() throws {
        let store = ProjectStore(directory: directory, seedDemo: false)
        let originalID = try store.create(title: "Original", before: image(.blue), after: image(.cyan))
        var original = try XCTUnwrap(store.project(id: originalID))
        original.annotations = [ImageAnnotation(x: 0.2, y: 0.3, text: "À conserver", side: .after)]
        original.zoom = 2.4
        original.panX = 0.45
        original.panY = -0.3
        try store.update(original)
        let copyID = try store.duplicate(id: originalID)
        let copy = try XCTUnwrap(store.project(id: copyID))
        XCTAssertNotEqual(copy.beforeFilename, original.beforeFilename)
        XCTAssertEqual(copy.annotations.first?.text, original.annotations.first?.text)
        XCTAssertNotEqual(copy.annotations.first?.id, original.annotations.first?.id)
        XCTAssertEqual(copy.zoom, original.zoom)
        XCTAssertEqual(copy.panX, original.panX)
        XCTAssertEqual(copy.panY, original.panY)
        try store.delete(id: originalID)
        XCTAssertNotNil(store.image(for: copy, side: .before))
    }

    @MainActor
    func testExportProducesValidPNGWithLongWrappedNotes() throws {
        let project = ComparisonProject(
            title: "Étude de lumière",
            beforeFilename: "before.jpg",
            afterFilename: "after.jpg",
            annotations: [
                ImageAnnotation(x: 0.1, y: 0.4, text: String(repeating: "Une note détaillée, avec accents et plusieurs mots. ", count: 20), side: .before)
            ]
        )
        let url = try ComparisonExporter.export(project: project, before: image(.blue), after: image(.orange))
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try Data(contentsOf: url)
        XCTAssertEqual(Array(data.prefix(8)), [137, 80, 78, 71, 13, 10, 26, 10])
        let exported = try XCTUnwrap(UIImage(data: data))
        XCTAssertEqual(exported.size.width, 1800)
        XCTAssertGreaterThan(exported.size.height, 1500)
    }

    @MainActor
    private func image(_ color: UIColor) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 48, height: 72), format: format).image { _ in
            color.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 48, height: 72))
        }
    }
}
