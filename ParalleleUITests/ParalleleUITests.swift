import XCTest

/// End-to-end checks run in a dedicated app-support directory.
/// The first launch resets that directory; relaunches deliberately preserve it.
@MainActor
final class ParalleleUITests: XCTestCase {
    private var app: XCUIApplication!
    private let launchArguments = [
        "--uitesting",
        "-AppleLanguages", "(fr)",
        "-AppleLocale", "fr_FR"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication()
        app.launchArguments = launchArguments + ["--reset-test-library"]
        app.launch()
        XCTAssertTrue(element("demoProject").waitForExistence(timeout: 15),
                      "La bibliothèque de test doit contenir la comparaison de démonstration.")
    }

    override func tearDownWithError() throws {
        if let testRun, testRun.failureCount > 0, app != nil {
            attachScreenshot(named: "État au moment de l’échec")
            let hierarchy = XCTAttachment(string: app.debugDescription)
            hierarchy.name = "Hiérarchie d’accessibilité au moment de l’échec"
            hierarchy.lifetime = .keepAlways
            add(hierarchy)
        }
        app?.terminate()
        app = nil
        XCUIDevice.shared.orientation = .portrait
    }

    func testDemoModesDividerAndLocalExport() throws {
        attachScreenshot(named: "01 — Bibliothèque")
        openDemo()

        selectMode("Balayage")
        let divider = element("comparisonDivider")
        XCTAssertTrue(divider.waitForExistence(timeout: 5),
                      "Le mode balayage doit présenter un séparateur réglable.")

        let oldValue = divider.value as? String
        let canvas = element("comparisonCanvas")
        divider.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.15,
                   thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.5)))
        if let oldValue {
            let changed = NSPredicate { object, _ in
                (object as? XCUIElement)?.value as? String != oldValue
            }
            expectation(for: changed, evaluatedWith: divider)
            waitForExpectations(timeout: 5)
        }
        attachScreenshot(named: "02 — Comparaison par balayage")

        selectMode("Côte à côte")
        waitForDisappearance(divider, message: "Le séparateur doit disparaître en mode côte à côte.")
        XCTAssertTrue(element("comparisonCanvas").exists)
        attachScreenshot(named: "03 — Comparaison côte à côte")

        let export = element("exportComparison")
        XCTAssertTrue(export.isEnabled)
        export.tap()
        let shareSheet = element("ActivityListView")
        XCTAssertTrue(shareSheet.waitForExistence(timeout: 15),
                      "L’export doit produire une fiche puis ouvrir la feuille de partage système.")
        XCTAssertTrue(app.cells["Enregistrer dans Fichiers"].waitForExistence(timeout: 5),
                      "La fiche générée doit être proposée à l’enregistrement dans la feuille système.")
        XCTAssertTrue(element("LP.CaptionBar.BottomCaption").label.contains("PNG"),
                      "Le système doit reconnaître le fichier exporté comme une image PNG.")
        attachScreenshot(named: "04 — Export local prêt à partager")
        dismissShareSheet(shareSheet)
        // The test never chooses a destination or transmits the exported file.
        XCTAssertTrue(element("backToLibrary").waitForExistence(timeout: 5))
    }

    func testAnnotationSurvivesClosingAndRelaunching() throws {
        openDemo()
        selectMode("Côte à côte")
        waitForDisappearance(element("comparisonDivider"),
                             message: "La comparaison doit être en mode côte à côte.")

        let add = element("addAnnotation")
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        // The centre of the first image pane remains inside its fitted image,
        // regardless of the screen size or the image's aspect ratio.
        element("comparisonCanvas")
            .coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
            .tap()

        let input = element("annotationText")
        XCTAssertTrue(input.waitForExistence(timeout: 5),
                      "Toucher une image doit ouvrir le formulaire d’annotation.")
        let save = element("saveAnnotation")
        XCTAssertFalse(save.isEnabled, "Une annotation vide ne doit pas être enregistrée.")
        let note = "La lumière et les couleurs sont plus douces."
        input.tap()
        input.typeText(note)
        XCTAssertTrue(save.isEnabled)
        save.tap()
        waitForDisappearance(input, message: "Le formulaire doit se fermer après l’enregistrement.")
        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 5))
        attachScreenshot(named: "05 — Annotation enregistrée")

        element("backToLibrary").tap()
        XCTAssertTrue(element("demoProject").waitForExistence(timeout: 5))
        openDemo()
        openSavedAnnotation(containing: note)
        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 5),
                      "La note doit rester accessible après avoir quitté et rouvert l’éditeur.")

        app.terminate()
        app.launchArguments = launchArguments
        app.launch()
        XCTAssertTrue(element("demoProject").waitForExistence(timeout: 15))
        openDemo()
        openSavedAnnotation(containing: note)
        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 5),
                      "La note doit être relue depuis le stockage après un redémarrage de l’app.")
        attachScreenshot(named: "06 — Annotation après redémarrage")
    }

    func testAnnotationContinuityWhenSimulatorActuallyResizes() throws {
        openDemo()
        selectMode("Côte à côte")
        waitForDisappearance(element("comparisonDivider"),
                             message: "La comparaison doit être en mode côte à côte.")
        element("addAnnotation").tap()
        element("comparisonCanvas")
            .coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5))
            .tap()
        let input = element("annotationText")
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let note = "Cette observation doit suivre le changement de format."
        input.tap()
        input.typeText(note)
        element("saveAnnotation").tap()
        waitForDisappearance(input, message: "L’annotation doit être enregistrée avant le redimensionnement.")
        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 5))
        let initialFrame = app.windows.firstMatch.frame
        attachScreenshot(named: "10 — Annotation avant demande de rotation")
        XCUIDevice.shared.orientation = .landscapeLeft
        let resized = NSPredicate { object, _ in
            guard let window = object as? XCUIElement else { return false }
            return abs(window.frame.width - initialFrame.width) > 1
                || abs(window.frame.height - initialFrame.height) > 1
        }
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: resized, object: app.windows.firstMatch)],
            timeout: 10
        )
        XCTAssertTrue(element("comparisonCanvas").exists)
        XCTAssertTrue(app.staticTexts[note].waitForExistence(timeout: 5),
                      "Le repère sélectionné doit rester affiché après la demande de rotation.")
        attachScreenshot(named: "11 — Annotation après demande de rotation")
        guard result == .completed else {
            throw XCTSkip(
                "XCUIDevice.orientation n’a produit aucun changement réel de dimensions "
                + "sur ce simulateur (\(Int(initialFrame.width)) × \(Int(initialFrame.height))). "
                + "La continuité après redimensionnement reste non vérifiée : "
                + "contrôler les poses ouverte, fermée et tournée dans Device Hub."
            )
        }
    }

    func testImportRequiresTitleAndBothImages() throws {
        element("newComparison").tap()
        let title = element("projectTitle")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        let create = element("createComparison")
        XCTAssertTrue(create.exists)
        XCTAssertFalse(create.isEnabled,
                       "La création doit rester désactivée quand les images et le titre sont absents.")
        XCTAssertTrue(element("pickOriginal").exists)
        XCTAssertTrue(element("pickRetouch").exists)
        let cancel = element("cancelImport")
        XCTAssertTrue(cancel.waitForExistence(timeout: 3),
                      "L’import doit proposer un bouton de fermeture accessible dans la barre native.")

        title.tap()
        title.typeText("Essai d’import")
        XCTAssertFalse(create.isEnabled,
                       "Un titre seul ne doit pas permettre de créer une comparaison sans images.")
        attachScreenshot(named: "07 — Import et validation")

        XCTAssertTrue(cancel.waitForExistence(timeout: 3),
                      "Le bouton de fermeture doit rester disponible pendant la saisie.")
        cancel.tap()
        XCTAssertTrue(element("demoProject").waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "demoProject").count, 1)
    }

    /// Requires at least two images in the simulator's Photos library.
    /// Seed with `simctl addmedia` before the run; the picker still performs
    /// the same limited-selection import as a real user.
    func testImportSelectedPhotosCreatesComparison() throws {
        element("newComparison").tap()
        XCTAssertTrue(element("projectTitle").waitForExistence(timeout: 5))
        selectPhoto(pickerIdentifier: "pickOriginal", index: 1)
        selectPhoto(pickerIdentifier: "pickRetouch", index: 0)

        let create = element("createComparison")
        XCTAssertFalse(create.isEnabled, "Deux images seules ne doivent pas remplacer un titre.")
        let title = element("projectTitle")
        title.tap()
        title.typeText("Import de validation\n")
        XCTAssertTrue(create.isEnabled, "Deux photos et un titre doivent autoriser la création.")
        if !create.isHittable {
            element("importScrollView").swipeUp()
        }
        attachScreenshot(named: "08 — Deux images sélectionnées")
        create.tap()

        XCTAssertTrue(element("comparisonCanvas").waitForExistence(timeout: 15),
                      "La nouvelle comparaison doit s’ouvrir une fois les images sauvegardées.")
        XCTAssertTrue(app.navigationBars["Import de validation"].exists)
        attachScreenshot(named: "09 — Comparaison importée")
        element("backToLibrary").tap()
        let importedCard = element("demoProject")
        XCTAssertTrue(importedCard.waitForExistence(timeout: 5))
        XCTAssertEqual(importedCard.label, "Import de validation",
                       "La nouvelle comparaison doit apparaître en tête de bibliothèque.")
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "projectCard-")).count,
            1,
            "La comparaison de démonstration doit rester présente après l’import."
        )
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func openDemo() {
        let card = element("demoProject")
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        XCTAssertTrue(element("comparisonCanvas").waitForExistence(timeout: 10))
        XCTAssertTrue(element("backToLibrary").exists)
    }

    private func selectMode(_ title: String) {
        let menu = element("comparisonMode")
        XCTAssertTrue(menu.waitForExistence(timeout: 5))
        menu.tap()
        let option = app.buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), "Le menu doit proposer le mode \(title).")
        option.tap()
    }

    private func openSavedAnnotation(containing text: String) {
        let pin = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(pin.waitForExistence(timeout: 5),
                      "Le repère enregistré doit être présent et accessible sur l’image.")
        pin.tap()
    }

    private func selectPhoto(pickerIdentifier: String, index: Int) {
        let picker = element(pickerIdentifier)
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.tap()
        let photoLibrary = app.scrollViews["photosView_content_scroll_view"]
        XCTAssertTrue(photoLibrary.waitForExistence(timeout: 10),
                      "Le sélecteur système doit présenter la photothèque préchargée.")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Sélecteur Photos — \(pickerIdentifier)"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)

        // Photos exposes its native grid as accessible images in a scroll view,
        // rather than UICollectionView cells. This excludes the onboarding icon.
        let photos = photoLibrary.images.matching(identifier: "PXGGridLayout-Info")
        let photo = photos.element(boundBy: index)
        XCTAssertTrue(photo.waitForExistence(timeout: 8),
                      "La photothèque doit exposer au moins deux images sélectionnables.")
        photo.tap()
        let imported = NSPredicate { object, _ in
            guard let element = object as? XCUIElement else { return false }
            return element.exists && element.label.hasPrefix("Remplacer")
        }
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: imported, object: picker)],
            timeout: 15
        )
        XCTAssertEqual(result, .completed, "L’image sélectionnée doit être décodée et affichée.")
        XCTAssertFalse(element("importError").exists)
    }

    private func dismissShareSheet(_ sheet: XCUIElement) {
        // These identifiers are exposed by the native activity controller.
        // Closing its header leaves every sharing destination untouched.
        let close = app.buttons["header.closeButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        close.tap()
        waitForDisappearance(sheet, message: "La feuille de partage doit se fermer sans transmission.")
    }

    private func waitForDisappearance(_ element: XCUIElement, message: String) {
        let predicate = NSPredicate(format: "exists == false")
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: element)],
                                   timeout: 6)
        XCTAssertEqual(result, .completed, message)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
