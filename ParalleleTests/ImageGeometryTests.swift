import XCTest
import CoreGraphics
@testable import Parallele

final class ImageGeometryTests: XCTestCase {
    func testLandscapeImageFitsWithinPortraitViewportWithoutCropping() {
        let frame = ImageGeometry.rect(
            image: CGSize(width: 4000, height: 2000),
            in: CGSize(width: 300, height: 600)
        )

        XCTAssertEqual(frame.minX, 0, accuracy: 0.001)
        XCTAssertEqual(frame.minY, 225, accuracy: 0.001)
        XCTAssertEqual(frame.width, 300, accuracy: 0.001)
        XCTAssertEqual(frame.height, 150, accuracy: 0.001)
    }

    func testPortraitImageFitsWithinLandscapeViewportWithoutCropping() {
        let frame = ImageGeometry.rect(
            image: CGSize(width: 2000, height: 4000),
            in: CGSize(width: 800, height: 400)
        )

        XCTAssertEqual(frame.minX, 300, accuracy: 0.001)
        XCTAssertEqual(frame.minY, 0, accuracy: 0.001)
        XCTAssertEqual(frame.width, 200, accuracy: 0.001)
        XCTAssertEqual(frame.height, 400, accuracy: 0.001)
    }

    func testLetterboxTouchesDoNotCreateAnnotations() {
        let frame = ImageGeometry.rect(
            image: CGSize(width: 4000, height: 2000),
            in: CGSize(width: 300, height: 600)
        )

        XCTAssertNil(ImageGeometry.normalized(CGPoint(x: 150, y: 100), in: frame))
        XCTAssertNil(ImageGeometry.normalized(CGPoint(x: 150, y: 500), in: frame))
        XCTAssertNil(ImageGeometry.normalized(CGPoint(x: -1, y: 300), in: frame))
        XCTAssertNotNil(ImageGeometry.normalized(CGPoint(x: 150, y: 300), in: frame))
    }

    func testZoomedAndPannedTouchMapsToTheUnderlyingImageDetail() throws {
        // The fitted photo is 400 × 200. At 2× zoom with this pan it spans
        // (-100, 0) to (700, 400). This visible point is a quarter across
        // the original image and three quarters down it.
        let frame = ImageGeometry.rect(
            image: CGSize(width: 4000, height: 2000),
            in: CGSize(width: 400, height: 600),
            zoom: 2,
            pan: CGSize(width: 0.25, height: -1.0 / 6.0)
        )
        let point = try XCTUnwrap(
            ImageGeometry.normalized(CGPoint(x: 100, y: 300), in: frame)
        )

        XCTAssertEqual(point.x, 0.25, accuracy: 0.0001)
        XCTAssertEqual(point.y, 0.75, accuracy: 0.0001)
        XCTAssertNil(ImageGeometry.normalized(CGPoint(x: 200, y: 500), in: frame))
    }

    func testNormalizedAnnotationSurvivesViewportResizeAndZoom() throws {
        let imageSize = CGSize(width: 3200, height: 2400)
        let detail = CGPoint(x: 0.23, y: 0.81)
        let compactFrame = ImageGeometry.rect(
            image: imageSize,
            in: CGSize(width: 390, height: 650)
        )
        let compactPoint = CGPoint(
            x: compactFrame.minX + compactFrame.width * detail.x,
            y: compactFrame.minY + compactFrame.height * detail.y
        )
        let saved = try XCTUnwrap(ImageGeometry.normalized(compactPoint, in: compactFrame))

        let expandedFrame = ImageGeometry.rect(
            image: imageSize,
            in: CGSize(width: 720, height: 600),
            zoom: 1.8,
            pan: CGSize(width: 0.08, height: -0.12)
        )
        let expandedPoint = CGPoint(
            x: expandedFrame.minX + expandedFrame.width * saved.x,
            y: expandedFrame.minY + expandedFrame.height * saved.y
        )
        let recovered = try XCTUnwrap(ImageGeometry.normalized(expandedPoint, in: expandedFrame))

        XCTAssertEqual(recovered.x, detail.x, accuracy: 0.0001)
        XCTAssertEqual(recovered.y, detail.y, accuracy: 0.0001)
    }

    func testInvalidImageDimensionsCannotProduceAnAnnotation() {
        for size in [
            CGSize.zero,
            CGSize(width: 400, height: 0),
            CGSize(width: 0, height: 400),
            CGSize(width: -1, height: 400)
        ] {
            let frame = ImageGeometry.rect(image: size, in: CGSize(width: 390, height: 650))
            XCTAssertEqual(frame, .zero)
            XCTAssertNil(ImageGeometry.normalized(.zero, in: frame))
        }
    }

    func testPanLimitsUseActualAspectFitOverflowInsteadOfZoomAlone() {
        let image = CGSize(width: 4000, height: 2000)
        let viewport = CGSize(width: 390, height: 650)
        let limits = ImageGeometry.panLimits(image: image, in: viewport, zoom: 4)

        XCTAssertEqual(limits.width, 1.5, accuracy: 0.0001)
        XCTAssertEqual(limits.height, 0.1, accuracy: 0.0001)
        let bounded = ImageGeometry.clampedPan(CGSize(width: 1.5, height: 1.5), limits: limits)
        let frame = ImageGeometry.rect(image: image, in: viewport, zoom: 4, pan: bounded)
        XCTAssertLessThanOrEqual(frame.minX, 0)
        XCTAssertLessThanOrEqual(frame.minY, 0)
        XCTAssertGreaterThanOrEqual(frame.maxX, viewport.width)
        XCTAssertGreaterThanOrEqual(frame.maxY, viewport.height)
    }

    func testZoomingOutRecentersLetterboxedAxisAndBoundsOtherAxis() {
        let image = CGSize(width: 4000, height: 2000)
        let viewport = CGSize(width: 390, height: 650)
        let bounded = ImageGeometry.clampedPan(
            CGSize(width: 1.5, height: 0.1),
            limits: ImageGeometry.panLimits(image: image, in: viewport, zoom: 1.5)
        )

        XCTAssertEqual(bounded.width, 0.25, accuracy: 0.0001)
        XCTAssertEqual(bounded.height, 0, accuracy: 0.0001)
        let frame = ImageGeometry.rect(image: image, in: viewport, zoom: 1.5, pan: bounded)
        XCTAssertEqual(frame.midY, viewport.height / 2, accuracy: 0.0001)
        XCTAssertTrue(frame.intersects(CGRect(origin: .zero, size: viewport)))
    }

    func testResizeReboundsSavedPanUsingNewPaneSize() {
        let image = CGSize(width: 4000, height: 2000)
        let oldViewport = CGSize(width: 800, height: 400)
        let newViewport = CGSize(width: 400, height: 700)
        let oldLimits = ImageGeometry.panLimits(image: image, in: oldViewport, zoom: 2)
        let newLimits = ImageGeometry.panLimits(image: image, in: newViewport, zoom: 2)
        let bounded = ImageGeometry.clampedPan(oldLimits, limits: newLimits)

        XCTAssertEqual(oldLimits.height, 0.5, accuracy: 0.0001)
        XCTAssertEqual(bounded.height, 0, accuracy: 0.0001)
        XCTAssertEqual(bounded.width, 0.5, accuracy: 0.0001)
        let frame = ImageGeometry.rect(image: image, in: newViewport, zoom: 2, pan: bounded)
        XCTAssertEqual(frame.midY, newViewport.height / 2, accuracy: 0.0001)
    }

    func testSharedPanCanRespectBothDifferentImageAspectRatios() {
        let viewport = CGSize(width: 390, height: 650)
        let landscape = ImageGeometry.panLimits(
            image: CGSize(width: 4000, height: 2000), in: viewport, zoom: 2
        )
        let portrait = ImageGeometry.panLimits(
            image: CGSize(width: 2000, height: 4000), in: viewport, zoom: 2
        )
        let common = CGSize(
            width: min(landscape.width, portrait.width),
            height: min(landscape.height, portrait.height)
        )
        let bounded = ImageGeometry.clampedPan(CGSize(width: 1, height: -1), limits: common)

        XCTAssertEqual(bounded.height, 0, accuracy: 0.0001)
        for image in [CGSize(width: 4000, height: 2000), CGSize(width: 2000, height: 4000)] {
            let frame = ImageGeometry.rect(image: image, in: viewport, zoom: 2, pan: bounded)
            XCTAssertTrue(frame.intersects(CGRect(origin: .zero, size: viewport)))
        }
    }
}
