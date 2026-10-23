import Foundation
import UIKit

enum ComparisonExportError: LocalizedError {
    case imageUnavailable
    case tooMuchContent
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .imageUnavailable:
            "Les deux images doivent être disponibles pour exporter cette comparaison."
        case .tooMuchContent:
            "Les annotations sont trop longues pour une seule image. Raccourcissez-les avant de réessayer."
        case .encodingFailed:
            "L’image de la comparaison n’a pas pu être créée."
        }
    }
}

@MainActor
enum ComparisonExporter {
    /// Renders an independent, shareable PNG. Photos remain uncropped and the
    /// comparison's current zoom does not affect the saved overview.
    static func export(project: ComparisonProject, before: UIImage, after: UIImage) throws -> URL {
        guard before.size.width > 0, before.size.height > 0,
              after.size.width > 0, after.size.height > 0 else {
            throw ComparisonExportError.imageUnavailable
        }
        let width: CGFloat = 1800
        let margin: CGFloat = 88
        let gap: CGFloat = 36
        let contentWidth = width - margin * 2
        let panelWidth = (contentWidth - gap) / 2
        let panelHeight: CGFloat = 1010
        let panelY: CGFloat = 298
        let ink = UIColor(red: 0.10, green: 0.12, blue: 0.15, alpha: 1)
        let muted = UIColor(red: 0.40, green: 0.43, blue: 0.48, alpha: 1)
        let background = UIColor(red: 0.965, green: 0.969, blue: 0.978, alpha: 1)

        let titleAttributes = attributes(font: .systemFont(ofSize: 68, weight: .semibold), color: ink)
        let noteAttributes = attributes(font: .systemFont(ofSize: 30), color: ink, lineSpacing: 8)
        let metaAttributes = attributes(font: .systemFont(ofSize: 26), color: muted)
        let labelAttributes = attributes(font: .systemFont(ofSize: 24, weight: .semibold), color: muted)
        let bodyX = margin + 70
        let bodyWidth = contentWidth - 70

        struct NoteLayout {
            let number: Int
            let annotation: ImageAnnotation
            let text: String
            let height: CGFloat
        }
        let notes: [NoteLayout] = project.annotations.enumerated().map { index, annotation in
            let text = annotation.text.trimmingCharacters(in: .whitespacesAndNewlines)
            let display = text.isEmpty ? "Sans commentaire" : text
            let measured = (display as NSString).boundingRect(
                with: CGSize(width: bodyWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: noteAttributes,
                context: nil
            )
            return NoteLayout(number: index + 1, annotation: annotation, text: display, height: ceil(measured.height))
        }
        let notesHeight = notes.reduce(CGFloat(0)) { $0 + $1.height + 94 }
        let notesY = panelY + panelHeight + 110
        let notesHeaderHeight: CGFloat = 112
        let totalHeight = notesY + (notes.isEmpty ? 0 : notesHeaderHeight + notesHeight) + 112
        guard totalHeight <= 22_000 else { throw ComparisonExportError.tooMuchContent }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: totalHeight), format: format)
        let output = renderer.image { rendererContext in
            let context = rendererContext.cgContext
            UIColor.white.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: width, height: totalHeight))

            let titleParagraph = NSMutableParagraphStyle()
            titleParagraph.lineBreakMode = .byTruncatingTail
            var fittedTitleAttributes = titleAttributes
            fittedTitleAttributes[.paragraphStyle] = titleParagraph
            (project.title as NSString).draw(
                in: CGRect(x: margin, y: 70, width: contentWidth, height: 90),
                withAttributes: fittedTitleAttributes
            )
            let date = project.updatedAt.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "fr_FR")))
            ("Comparaison visuelle · \(date)" as NSString).draw(
                at: CGPoint(x: margin, y: 178), withAttributes: metaAttributes
            )

            let panels: [(ImageSide, UIImage, CGRect)] = [
                (.before, before, CGRect(x: margin, y: panelY, width: panelWidth, height: panelHeight)),
                (.after, after, CGRect(x: margin + panelWidth + gap, y: panelY, width: panelWidth, height: panelHeight))
            ]
            for (side, image, panel) in panels {
                (side.title.uppercased() as NSString).draw(
                    at: CGPoint(x: panel.minX, y: panelY - 48), withAttributes: labelAttributes
                )
                background.setFill()
                UIBezierPath(roundedRect: panel, cornerRadius: 24).fill()
                let imageRect = aspectFit(image.size, in: panel.insetBy(dx: 20, dy: 20))
                context.saveGState()
                UIBezierPath(roundedRect: panel, cornerRadius: 24).addClip()
                image.draw(in: imageRect)
                context.restoreGState()

                for note in notes where note.annotation.side == side {
                    let x = note.annotation.x.isFinite ? min(1, max(0, note.annotation.x)) : 0.5
                    let y = note.annotation.y.isFinite ? min(1, max(0, note.annotation.y)) : 0.5
                    let point = CGPoint(x: imageRect.minX + imageRect.width * x, y: imageRect.minY + imageRect.height * y)
                    drawPin(note.number, center: point, color: statusColor(note.annotation.status), context: context)
                }
            }

            if !notes.isEmpty {
                ("Annotations" as NSString).draw(
                    at: CGPoint(x: margin, y: notesY),
                    withAttributes: attributes(font: .systemFont(ofSize: 36, weight: .semibold), color: ink)
                )
                let summary = "\(project.pendingAnnotationCount) à corriger · "
                    + "\(project.validatedAnnotationCount) validé\(project.validatedAnnotationCount > 1 ? "s" : "")"
                (summary as NSString).draw(
                    at: CGPoint(x: margin, y: notesY + 52), withAttributes: metaAttributes
                )
                var y = notesY + notesHeaderHeight
                for note in notes {
                    let statusInk = statusColor(note.annotation.status)
                    drawPin(note.number, center: CGPoint(x: margin + 22, y: y + 20), color: statusInk, context: context, radius: 22)
                    let metadata = "\(note.annotation.side.title) · \(note.annotation.status.title)".uppercased()
                    (metadata as NSString).draw(
                        at: CGPoint(x: bodyX, y: y),
                        withAttributes: attributes(font: .systemFont(ofSize: 24, weight: .semibold), color: statusInk)
                    )
                    (note.text as NSString).draw(
                        in: CGRect(x: bodyX, y: y + 42, width: bodyWidth, height: note.height + 8),
                        withAttributes: noteAttributes
                    )
                    y += note.height + 94
                }
            }

            ("PARALLÈLE  /  Deux images, un regard." as NSString).draw(
                at: CGPoint(x: margin, y: totalHeight - 70),
                withAttributes: attributes(font: .systemFont(ofSize: 22, weight: .medium), color: muted)
            )
        }
        guard let data = output.pngData() else { throw ComparisonExportError.encodingFailed }
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ParalleleExports", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Parallele-\(UUID().uuidString).png")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The written status accompanies every marker, so color is never the only
    /// way to distinguish a pending observation from a validated one.
    private static func statusColor(_ status: AnnotationStatus) -> UIColor {
        switch status {
        case .toReview: UIColor(red: 0.06, green: 0.40, blue: 0.78, alpha: 1)
        case .validated: UIColor(red: 0.17, green: 0.43, blue: 0.31, alpha: 1)
        }
    }

    private static func attributes(font: UIFont, color: UIColor, lineSpacing: CGFloat = 0) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing
        paragraph.lineBreakMode = .byWordWrapping
        return [.font: font, .foregroundColor: color, .paragraphStyle: paragraph]
    }

    private static func aspectFit(_ size: CGSize, in rect: CGRect) -> CGRect {
        let scale = min(rect.width / size.width, rect.height / size.height)
        let fitted = CGSize(width: size.width * scale, height: size.height * scale)
        return CGRect(
            x: rect.midX - fitted.width / 2,
            y: rect.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
    }

    private static func drawPin(_ number: Int, center: CGPoint, color: UIColor, context: CGContext, radius: CGFloat = 26) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 7, color: UIColor.black.withAlphaComponent(0.22).cgColor)
        color.setFill()
        UIBezierPath(ovalIn: rect).fill()
        context.restoreGState()
        UIColor.white.setStroke()
        let outline = UIBezierPath(ovalIn: rect)
        outline.lineWidth = 3
        outline.stroke()
        let text = String(number) as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedDigitSystemFont(ofSize: number > 99 ? 17 : 23, weight: .semibold),
            .foregroundColor: UIColor.white
        ]
        let size = text.size(withAttributes: attrs)
        text.draw(at: CGPoint(x: center.x - size.width / 2, y: center.y - size.height / 2), withAttributes: attrs)
    }
}
