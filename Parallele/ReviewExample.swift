import UIKit

@MainActor
extension ProjectStore {
    /// Creates an editable, fictional review only when the user asks for it.
    /// Existing comparisons and the initial photographic demo are preserved.
    func createReviewExample() throws -> ComparisonProject {
        let id = try create(
            title: "Revue d’interface — Atelier",
            before: ReviewExampleArtwork.image(revised: false),
            after: ReviewExampleArtwork.image(revised: true)
        )
        do {
            guard var example = project(id: id) else { throw ProjectStoreError.missingProject }
            var notes = [
                ImageAnnotation(
                    x: 87.0 / 428, y: 510.0 / 720,
                    text: "Réservation — Le bouton Après est plus visible et affiche le prix. Vérifier que l’action principale se repère au premier regard.",
                    side: .before
                ),
                ImageAnnotation(
                    x: 119.0 / 428, y: 566.0 / 720,
                    text: "Date et lieu — Dans Après, ces informations précèdent le bouton. Vérifier qu’elles se lisent avant de réserver.",
                    side: .before
                ),
                ImageAnnotation(
                    x: 304.0 / 428, y: 391.0 / 720,
                    text: "Hiérarchie — Le titre Après se distingue mieux du descriptif grâce au poids du texte et au contraste.",
                    side: .after
                )
            ]
            notes[0].status = .toReview
            notes[1].status = .toReview
            notes[2].status = .validated
            example.annotations = notes
            example.mode = .automatic
            try update(example)
            guard let saved = project(id: id) else { throw ProjectStoreError.missingProject }
            return saved
        } catch {
            // Roll back only this newly created example if its review cannot be saved.
            try? delete(id: id)
            throw error
        }
    }
}

/// A pair of screenshots of the same fictional booking screen. All artwork is
/// local and deterministic; generating it needs neither Photos nor the network.
@MainActor
private enum ReviewExampleArtwork {
    private static let size = CGSize(width: 428, height: 720)
    private static let paper = color(0xF8F7F3)
    private static let ink = color(0x24231F)
    private static let muted = color(0x77746D)
    private static let faint = color(0x96938C)
    private static let accent = color(0x9F482F)

    static func image(revised: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            paper.setFill()
            renderer.fill(CGRect(origin: .zero, size: size))
            drawHeader()
            drawCeramics(in: CGRect(x: 24, y: 88, width: 380, height: 214),
                         context: renderer.cgContext)

            text("CÉRAMIQUE · INITIATION", in: CGRect(x: 24, y: 321, width: 380, height: 18),
                 size: 11, weight: .semibold, color: revised ? accent : muted, tracking: 1.3)
            text("Façonnez\nvotre première pièce.", in: CGRect(x: 24, y: 347, width: 380, height: 80),
                 size: 31, weight: revised ? .semibold : .regular,
                 color: revised ? ink : faint, lineSpacing: 1, tracking: -0.9)
            text("Un moment pour créer, guidé par Léa.",
                 in: CGRect(x: 24, y: 439, width: 380, height: 28),
                 size: 16, color: revised ? color(0x57554E) : faint)

            if revised {
                drawRevisedBooking()
            } else {
                drawInitialBooking()
            }
            text("Matériel inclus · 8 places", in: CGRect(x: 24, y: 625, width: 380, height: 20),
                 size: 13, color: muted, alignment: .center)
            drawNavigation()
        }
    }

    private static func drawHeader() {
        text("studio", in: CGRect(x: 24, y: 22, width: 140, height: 36),
             size: 29, weight: .semibold, color: ink, tracking: -1.5)
        rounded(CGRect(x: 288, y: 29, width: 116, height: 25), radius: 12.5,
                fill: color(0xEEEBE4))
        text("EXEMPLE FICTIF", in: CGRect(x: 293, y: 36, width: 106, height: 14),
             size: 9, weight: .semibold, color: muted, alignment: .center, tracking: 0.8)
        line(from: CGPoint(x: 24, y: 69), to: CGPoint(x: 404, y: 69), color: color(0xE5E1D8))
    }

    private static func drawInitialBooking() {
        rounded(CGRect(x: 24, y: 493, width: 128, height: 34), radius: 17,
                fill: color(0xF0EEE8), stroke: color(0xD8D3C9))
        text("Réserver", in: CGRect(x: 30, y: 502, width: 116, height: 21),
             size: 14, weight: .medium, color: muted, alignment: .center)
        text("45 € / personne", in: CGRect(x: 170, y: 502, width: 220, height: 22),
             size: 14, color: muted)
        text("Sam. 14 novembre · 14 h 30", in: CGRect(x: 24, y: 559, width: 380, height: 20),
             size: 13, color: faint)
        text("Studio Belleville · Paris 20e", in: CGRect(x: 24, y: 584, width: 380, height: 22),
             size: 14, color: faint)
    }

    private static func drawRevisedBooking() {
        rounded(CGRect(x: 24, y: 484, width: 380, height: 65), radius: 15, fill: color(0xEEEBE4))
        symbol("calendar", in: CGRect(x: 41, y: 504, width: 24, height: 24), color: ink)
        text("Sam. 14 novembre · 14 h 30", in: CGRect(x: 80, y: 495, width: 306, height: 23),
             size: 15, weight: .semibold, color: ink)
        text("Studio Belleville · Paris 20e", in: CGRect(x: 80, y: 520, width: 306, height: 21),
             size: 13, color: color(0x57554E))
        rounded(CGRect(x: 24, y: 566, width: 380, height: 54), radius: 27, fill: accent)
        text("Réserver", in: CGRect(x: 46, y: 583, width: 190, height: 26),
             size: 17, weight: .semibold, color: .white)
        text("45 €", in: CGRect(x: 271, y: 583, width: 78, height: 26),
             size: 17, weight: .medium, color: .white, alignment: .right)
        symbol("arrow.right", in: CGRect(x: 365, y: 585, width: 17, height: 17), color: .white)
    }

    private static func drawNavigation() {
        line(from: CGPoint(x: 0, y: 660), to: CGPoint(x: 428, y: 660), color: color(0xE5E1D8))
        let items: [(String, String, CGFloat)] = [
            ("safari", "Découvrir", 78), ("ticket", "Réservations", 214), ("person.crop.circle", "Profil", 350)
        ]
        for (index, item) in items.enumerated() {
            let tint = index == 0 ? accent : muted
            symbol(item.0, in: CGRect(x: item.2 - 11, y: 673, width: 22, height: 22), color: tint)
            text(item.1, in: CGRect(x: item.2 - 62, y: 701, width: 124, height: 17),
                 size: 10, weight: index == 0 ? .semibold : .regular, color: tint, alignment: .center)
        }
    }

    private static func drawCeramics(in rect: CGRect, context: CGContext) {
        context.saveGState()
        UIBezierPath(roundedRect: rect, cornerRadius: 20).addClip()
        context.translateBy(x: rect.minX, y: rect.minY)
        let palette = [color(0xDCC5B2).cgColor, color(0xCDAA91).cgColor] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: palette,
                                     locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 380, y: 214), options: [])
        }

        color(0xE9D8C8).setFill()
        UIBezierPath(ovalIn: CGRect(x: -37, y: -38, width: 261, height: 261)).fill()
        let arch = UIBezierPath(roundedRect: CGRect(x: 277, y: -26, width: 148, height: 268),
                                cornerRadius: 74)
        color(0xBA8266).setFill()
        arch.fill()
        color(0xC59E83).setFill()
        UIRectFill(CGRect(x: 0, y: 177, width: 380, height: 37))

        for shadow in [CGRect(x: 46, y: 179, width: 120, height: 14),
                       CGRect(x: 142, y: 183, width: 99, height: 16),
                       CGRect(x: 244, y: 181, width: 86, height: 12)] {
            color(0x81523D).withAlphaComponent(0.17).setFill()
            UIBezierPath(ovalIn: shadow).fill()
        }
        vase(in: CGRect(x: 150, y: 43, width: 83, height: 148), fill: color(0xA45738), context: context)
        vase(in: CGRect(x: 253, y: 100, width: 65, height: 86), fill: color(0xEADBC4), context: context)

        let bowl = UIBezierPath()
        bowl.move(to: CGPoint(x: 51, y: 137))
        bowl.addCurve(to: CGPoint(x: 76, y: 187), controlPoint1: CGPoint(x: 53, y: 165),
                      controlPoint2: CGPoint(x: 64, y: 186))
        bowl.addLine(to: CGPoint(x: 131, y: 187))
        bowl.addCurve(to: CGPoint(x: 157, y: 137), controlPoint1: CGPoint(x: 146, y: 184),
                      controlPoint2: CGPoint(x: 153, y: 165))
        bowl.close()
        color(0xEDE4D1).setFill()
        bowl.fill()
        color(0xBC9E7B).setFill()
        UIBezierPath(ovalIn: CGRect(x: 51, y: 127, width: 106, height: 20)).fill()
        color(0xDFCCAF).setFill()
        UIBezierPath(ovalIn: CGRect(x: 57, y: 130, width: 94, height: 12)).fill()

        text("LE TEMPS DE CRÉER", in: CGRect(x: 17, y: 17, width: 240, height: 18),
             size: 10, weight: .semibold, color: color(0x624532), tracking: 1.4)
        context.restoreGState()
    }

    private static func vase(in rect: CGRect, fill: UIColor, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.minY)
        context.scaleBy(x: rect.width, y: rect.height)
        let body = UIBezierPath()
        body.move(to: CGPoint(x: 0.33, y: 0.02))
        body.addLine(to: CGPoint(x: 0.67, y: 0.02))
        body.addCurve(to: CGPoint(x: 0.95, y: 0.62), controlPoint1: CGPoint(x: 0.62, y: 0.27),
                      controlPoint2: CGPoint(x: 0.96, y: 0.33))
        body.addCurve(to: CGPoint(x: 0.73, y: 1), controlPoint1: CGPoint(x: 0.96, y: 0.89),
                      controlPoint2: CGPoint(x: 0.83, y: 1))
        body.addLine(to: CGPoint(x: 0.27, y: 1))
        body.addCurve(to: CGPoint(x: 0.05, y: 0.62), controlPoint1: CGPoint(x: 0.17, y: 1),
                      controlPoint2: CGPoint(x: 0.04, y: 0.89))
        body.addCurve(to: CGPoint(x: 0.33, y: 0.02), controlPoint1: CGPoint(x: 0.04, y: 0.33),
                      controlPoint2: CGPoint(x: 0.38, y: 0.27))
        body.close()
        fill.setFill()
        body.fill()
        context.saveGState()
        body.addClip()
        UIColor.white.withAlphaComponent(0.09).setFill()
        UIBezierPath(ovalIn: CGRect(x: 0.02, y: 0.17, width: 0.48, height: 1)).fill()
        context.restoreGState()
        fill.withAlphaComponent(0.9).setFill()
        UIBezierPath(ovalIn: CGRect(x: 0.32, y: 0, width: 0.36, height: 0.045)).fill()
        color(0x60422F).withAlphaComponent(0.4).setFill()
        UIBezierPath(ovalIn: CGRect(x: 0.36, y: 0.007, width: 0.28, height: 0.022)).fill()
        context.restoreGState()
    }

    private static func text(_ string: String, in rect: CGRect, size: CGFloat,
                             weight: UIFont.Weight = .regular, color: UIColor,
                             alignment: NSTextAlignment = .left, lineSpacing: CGFloat = 0,
                             tracking: CGFloat = 0) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.lineSpacing = lineSpacing
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color, .paragraphStyle: paragraph, .kern: tracking
        ]
        (string as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading],
                                 attributes: attributes, context: nil)
    }

    private static func symbol(_ name: String, in rect: CGRect, color: UIColor) {
        let configuration = UIImage.SymbolConfiguration(pointSize: rect.height, weight: .regular)
        guard let image = UIImage(systemName: name, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else { return }
        let scale = min(rect.width / image.size.width, rect.height / image.size.height)
        let fitted = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        image.draw(in: CGRect(x: rect.midX - fitted.width / 2, y: rect.midY - fitted.height / 2,
                              width: fitted.width, height: fitted.height))
    }

    private static func rounded(_ rect: CGRect, radius: CGFloat, fill: UIColor, stroke: UIColor? = nil) {
        let shape = UIBezierPath(roundedRect: rect, cornerRadius: radius)
        fill.setFill()
        shape.fill()
        if let stroke {
            stroke.setStroke()
            shape.lineWidth = 1
            shape.stroke()
        }
    }

    private static func line(from start: CGPoint, to end: CGPoint, color: UIColor) {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        path.lineWidth = 1
        color.setStroke()
        path.stroke()
    }

    private static func color(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}
