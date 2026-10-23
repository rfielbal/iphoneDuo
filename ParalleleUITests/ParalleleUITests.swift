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

    private var isDeviceHubFoldTest: Bool {
        name.contains("testAnnotationsSurviveDeviceHubFoldTransitions")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        if isDeviceHubFoldTest,
           ProcessInfo.processInfo.environment["PARALLELE_FOLD_TEST"] != "1" {
            throw XCTSkip("Parcours Device Hub piloté : activer TEST_RUNNER_PARALLELE_FOLD_TEST=1 et sélectionner ce test seul.")
        }
        if !isDeviceHubFoldTest { XCUIDevice.shared.orientation = .portrait }
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
        if !isDeviceHubFoldTest { XCUIDevice.shared.orientation = .portrait }
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

    func testReviewStatusFiltersAndSurvivesRelaunch() throws {
        createReviewExample()
        element("showAnnotations").tap()
        assertReviewRows([0, 1, 2])
        XCTAssertEqual(element("annotationReviewSummary").label, "2 à corriger · 1 validé")

        selectAnnotationFilter("À corriger")
        assertReviewRows([0, 1])
        element("annotationRow-0").tap()
        waitForDisappearance(element("annotationFilter"), message: "Choisir une note doit fermer la liste.")
        assertAnnotationStatus("À corriger")
        element("toggleAnnotationStatus").tap()
        assertAnnotationStatus("Validé")

        element("showAnnotations").tap()
        // A status change must move the same note between filters, not create
        // a duplicate or renumber the remaining observations.
        assertReviewRows([1])
        XCTAssertEqual(element("annotationReviewSummary").label, "1 à corriger · 2 validés")
        selectAnnotationFilter("Validé")
        assertReviewRows([0, 2])
        attachScreenshot(named: "Revue — deux observations validées")
        element("closeAnnotations").tap()
        element("backToLibrary").tap()
        XCTAssertTrue(reviewExampleCard.waitForExistence(timeout: 5))

        app.terminate()
        app.launchArguments = launchArguments
        app.launch()
        XCTAssertTrue(reviewExampleCard.waitForExistence(timeout: 15))
        reviewExampleCard.tap()
        XCTAssertTrue(element("comparisonCanvas").waitForExistence(timeout: 10))
        element("showAnnotations").tap()
        assertReviewRows([0, 1, 2])
        selectAnnotationFilter("Validé")
        assertReviewRows([0, 2])
        element("annotationRow-0").tap()
        assertAnnotationStatus("Validé")

        // Validation remains reversible after loading the saved project.
        element("toggleAnnotationStatus").tap()
        assertAnnotationStatus("À corriger")
        element("showAnnotations").tap()
        assertReviewRows([2])
        selectAnnotationFilter("À corriger")
        assertReviewRows([0, 1])
        selectAnnotationFilter("Toutes")
        assertReviewRows([0, 1, 2])
        attachScreenshot(named: "Revue — état relu et correction réouverte")
    }

    func testReviewExampleCreatesSeparateProjectWithoutPhotoImport() throws {
        let original = element("demoProject")
        let originalTitle = original.label
        let originalValue = original.value as? String
        XCTAssertFalse(reviewExampleCard.exists, "L’exemple doit être créé à la demande.")

        createReviewExample()
        XCTAssertFalse(app.scrollViews["photosView_content_scroll_view"].exists,
                       "L’exemple embarqué doit s’ouvrir sans sélectionner de photos personnelles.")
        XCTAssertFalse(element("projectTitle").exists,
                       "L’exemple ne doit pas passer par le formulaire d’import.")
        element("showAnnotations").tap()
        assertReviewRows([0, 1, 2])
        XCTAssertEqual(element("annotationReviewSummary").label, "2 à corriger · 1 validé")
        element("closeAnnotations").tap()
        element("backToLibrary").tap()
        XCTAssertTrue(reviewExampleCard.waitForExistence(timeout: 5))

        // Search also works when the existing card falls below the viewport.
        // The first-card identifier changes when the new project is inserted.
        let search = app.searchFields.firstMatch
        if !search.exists {
            let openSearch = app.buttons["Rechercher"]
            XCTAssertTrue(openSearch.waitForExistence(timeout: 5))
            openSearch.tap()
        }
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText(originalTitle)
        let preserved = app.buttons.matching(NSPredicate(format: "label == %@", originalTitle)).firstMatch
        XCTAssertTrue(preserved.waitForExistence(timeout: 5),
                      "Créer l’exemple doit conserver la comparaison déjà présente.")
        XCTAssertEqual(preserved.value as? String, originalValue,
                       "La comparaison existante doit conserver son nombre d’annotations.")
        preserved.tap()
        XCTAssertTrue(element("comparisonCanvas").waitForExistence(timeout: 10))
        element("showAnnotations").tap()
        XCTAssertTrue(element("annotationFilter").waitForExistence(timeout: 5))
        XCTAssertFalse(element("annotationRow-0").exists,
                       "Les trois notes de l’exemple ne doivent pas être ajoutées à l’ancien projet.")
        attachScreenshot(named: "Revue — comparaison initiale conservée")
    }

    /// Run this method alone with TEST_RUNNER_PARALLELE_FOLD_TEST=1.
    /// xcodebuild removes TEST_RUNNER_ when forwarding the variable to this runner.
    /// Prepare Device Hub in Closed, then follow the READY_ signals. Only an
    /// observed window or image-layout change advances the test.
    func testAnnotationsSurviveDeviceHubFoldTransitions() throws {
        openDemo()
        selectMode("Balayage")
        let divider = element("comparisonDivider")
        XCTAssertTrue(divider.waitForExistence(timeout: 5))
        XCTAssertEqual(divider.value as? String, "50 pour cent",
                       "Le placement doit commencer avec une séparation A/B au milieu.")

        let noteA = "A : la courbe de l’escalier reste mon repère."
        let noteB = "B : la lumière chaude reste attachée à l’image."
        addFoldAnnotation(noteA, at: CGVector(dx: 0.40, dy: 0.42))
        addFoldAnnotation(noteB, at: CGVector(dx: 0.60, dy: 0.58))
        closeFoldCallout()
        let anchors = [
            captureFoldAnchor(pin: "annotationPin-0", image: "comparisonImage-before", text: noteA),
            captureFoldAnchor(pin: "annotationPin-1", image: "comparisonImage-after", text: noteB)
        ]
        selectMode("Automatique")
        let closedWindow = app.windows.firstMatch.frame
        let closedCanvas = element("comparisonCanvas").frame
        XCTAssertTrue(divider.exists, "Le départ Closed doit utiliser la présentation compacte automatique.")
        verifyFoldStage("00_CLOSED", anchors: anchors)
        let closedImages = anchors.map { element($0.imageIdentifier).frame }

        waitForDeviceHubPose("READY_OPEN", anchors: anchors) { [self] in
            isExpanded(comparedWith: closedWindow)
        }
        waitForDisappearance(divider, message: "Le mode Auto doit présenter les deux images une fois le Duo ouvert.")
        verifyFoldStage("01_OPEN", anchors: anchors)

        // The operator may inspect Partially Open during this wait. It must not
        // satisfy Closed merely because one frame changed: both geometries must
        // return to their recorded compact dimensions.
        waitForDeviceHubPose("READY_CLOSED", anchors: anchors) { [self] in
            sameDimensions(app.windows.firstMatch.frame, closedWindow)
                && sameDimensions(element("comparisonCanvas").frame, closedCanvas)
        }
        XCTAssertTrue(divider.waitForExistence(timeout: 5),
                      "La fermeture doit retrouver le balayage automatique et les deux repères.")
        XCTAssertEqual(divider.value as? String, "50 pour cent")
        verifyFoldStage("02_CLOSED_AGAIN", anchors: anchors)

        waitForDeviceHubPose("READY_REOPEN", anchors: anchors) { [self] in
            isExpanded(comparedWith: closedWindow)
        }
        waitForDisappearance(divider, message: "La réouverture doit rétablir la présentation étendue.")
        verifyFoldStage("03_REOPENED", anchors: anchors)
        let openImages = anchors.map { element($0.imageIdentifier).frame }

        let imageBeforeZoom = element("comparisonImage-before").frame
        element("zoomComparison").tap()
        let enlarged = NSPredicate { [self] _, _ in
            let frame = element("comparisonImage-before").frame
            return frame.width > imageBeforeZoom.width * 1.8
                && frame.height > imageBeforeZoom.height * 1.8
        }
        let zoomResult = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: enlarged, object: nil)], timeout: 6
        )
        XCTAssertEqual(zoomResult, .completed,
                       "Le zoom 2× doit agrandir réellement l’image exposée, sans se limiter au libellé du bouton.")
        verifyFoldStage("04_OPEN_ZOOM", anchors: anchors)

        waitForDeviceHubPose("READY_ZOOM_CLOSED", anchors: anchors) { [self] in
            sameDimensions(app.windows.firstMatch.frame, closedWindow)
                && sameDimensions(element("comparisonCanvas").frame, closedCanvas)
        }
        XCTAssertTrue(divider.waitForExistence(timeout: 5))
        XCTAssertEqual(divider.value as? String, "50 pour cent")
        verifyFoldStage("05_CLOSED_ZOOM", anchors: anchors)
        assertFoldZoom(2, anchors: anchors, unzoomedFrames: closedImages)

        waitForDeviceHubPose("READY_ZOOM_REOPEN", anchors: anchors) { [self] in
            isExpanded(comparedWith: closedWindow)
        }
        waitForDisappearance(divider, message: "La réouverture doit conserver le zoom dans la présentation étendue.")
        verifyFoldStage("06_REOPENED_ZOOM", anchors: anchors)
        assertFoldZoom(2, anchors: anchors, unzoomedFrames: openImages)

        let openZoomWindow = app.windows.firstMatch.frame
        let openZoomBefore = element("comparisonImage-before").frame
        let openZoomAfter = element("comparisonImage-after").frame
        waitForDeviceHubPose("READY_PARTIAL", anchors: anchors) { [self] in
            let before = element("comparisonImage-before")
            let after = element("comparisonImage-after")
            guard before.exists, after.exists,
                  sameDimensions(app.windows.firstMatch.frame, openZoomWindow) else { return false }
            return before.frame.width < openZoomBefore.width - 2
                || abs(after.frame.minX - openZoomAfter.minX) > 2
                || abs(after.frame.minY - openZoomAfter.minY) > 2
        }
        verifyFoldStage("07_PARTIAL_ZOOM", anchors: anchors)

        let partialZoomBefore = element("comparisonImage-before").frame
        element("zoomComparison").tap()
        let restored = NSPredicate { [self] _, _ in
            let frame = element("comparisonImage-before").frame
            return frame.width < partialZoomBefore.width * 0.6
                && frame.height < partialZoomBefore.height * 0.6
        }
        let restoreResult = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: restored, object: nil)], timeout: 6
        )
        XCTAssertEqual(restoreResult, .completed,
                       "Le retour à 1× doit réduire réellement l’image dans la pose intermédiaire.")
        verifyFoldStage("08_PARTIAL", anchors: anchors)
        let availablePane = element("comparisonImage-after").frame
        for identifier in ["comparisonMode", "addAnnotation", "zoomComparison"] {
            let control = element(identifier)
            XCTAssertGreaterThanOrEqual(control.frame.minX, availablePane.minX - 2,
                                        "08_PARTIAL : \(identifier) doit rester à droite de la charnière.")
            XCTAssertLessThanOrEqual(control.frame.maxX, availablePane.maxX + 2,
                                     "08_PARTIAL : \(identifier) doit rester dans le panneau disponible.")
        }
        let add = element("addAnnotation")
        add.tap()
        XCTAssertTrue(app.buttons["Annuler le repère"].waitForExistence(timeout: 5),
                      "Le bouton du dock déplacé doit permettre de commencer un placement.")
        attachScreenshot(named: "Duo — 08_PARTIAL — placement activé hors charnière")
        add.tap()
        XCTAssertTrue(app.buttons["Ajouter une annotation"].waitForExistence(timeout: 5),
                      "Le placement doit pouvoir être annulé depuis le même bouton.")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "annotationPin-")).count,
                       anchors.count, "L’annulation ne doit ajouter ni supprimer de repère.")
        foldLog("COMPLETE — pliages à 1× et 2×, pose intermédiaire, deux repères alignés et relisibles.")
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

    private struct FoldAnchor {
        let pinIdentifier: String
        let imageIdentifier: String
        let text: String
        let normalized: CGPoint
    }

    private func addFoldAnnotation(_ text: String, at location: CGVector) {
        element("addAnnotation").tap()
        element("comparisonCanvas").coordinate(withNormalizedOffset: location).tap()
        let input = element("annotationText")
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        input.typeText(text)
        element("saveAnnotation").tap()
        waitForDisappearance(input, message: "La note doit être enregistrée avant le changement de pose.")
        XCTAssertTrue(app.staticTexts[text].waitForExistence(timeout: 5))
    }

    private func closeFoldCallout() {
        let close = app.buttons["Fermer le repère"]
        if close.exists { close.tap() }
    }

    private func captureFoldAnchor(pin pinIdentifier: String, image imageIdentifier: String,
                                   text: String) -> FoldAnchor {
        let pin = element(pinIdentifier)
        let image = element(imageIdentifier)
        XCTAssertTrue(pin.waitForExistence(timeout: 5))
        XCTAssertTrue(image.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(image.frame.width, 0)
        XCTAssertGreaterThan(image.frame.height, 0)
        let point = CGPoint(x: (pin.frame.midX - image.frame.minX) / image.frame.width,
                            y: (pin.frame.midY - image.frame.minY) / image.frame.height)
        XCTAssertTrue((0...1).contains(point.x) && (0...1).contains(point.y),
                      "Le repère doit être placé à l’intérieur de l’image de référence.")
        return FoldAnchor(pinIdentifier: pinIdentifier, imageIdentifier: imageIdentifier,
                          text: text, normalized: point)
    }

    private func sameDimensions(_ first: CGRect, _ second: CGRect) -> Bool {
        abs(first.width - second.width) <= 2 && abs(first.height - second.height) <= 2
    }

    private func assertFoldZoom(_ scale: CGFloat, anchors: [FoldAnchor], unzoomedFrames: [CGRect]) {
        for (anchor, baseline) in zip(anchors, unzoomedFrames) {
            let current = element(anchor.imageIdentifier).frame
            XCTAssertEqual(current.width, baseline.width * scale, accuracy: 2,
                           "Le pliage doit conserver le facteur de zoom de chaque image.")
            XCTAssertEqual(current.height, baseline.height * scale, accuracy: 2)
        }
    }

    private func isExpanded(comparedWith closed: CGRect) -> Bool {
        let current = app.windows.firstMatch.frame
        let canvas = element("comparisonCanvas").frame
        return current.width * current.height > closed.width * closed.height * 1.2
            && canvas.width >= 560
    }

    private func waitForDeviceHubPose(_ signal: String, anchors: [FoldAnchor],
                                      condition: @escaping () -> Bool) {
        attachFoldGeometry("BEFORE_\(signal)", anchors: anchors)
        foldLog("\(signal) — action Device Hub attendue ; délai maximal 120 secondes.")
        let predicate = NSPredicate { _, _ in condition() }
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)],
            timeout: 120
        )
        if result != .completed {
            attachFoldGeometry("TIMEOUT_\(signal)", anchors: anchors)
            attachScreenshot(named: "Duo — délai dépassé \(signal)")
        }
        XCTAssertEqual(result, .completed,
                       "\(signal) : aucun changement réel vers les dimensions attendues n’a été observé.")
    }

    private func verifyFoldStage(_ stage: String, anchors: [FoldAnchor]) {
        let aligned = NSPredicate { [self] _, _ in
            anchors.allSatisfy { anchor in
                let image = element(anchor.imageIdentifier)
                let pin = element(anchor.pinIdentifier)
                guard image.exists, pin.exists, image.frame.width > 0, image.frame.height > 0 else { return false }
                let expected = CGPoint(x: image.frame.minX + image.frame.width * anchor.normalized.x,
                                       y: image.frame.minY + image.frame.height * anchor.normalized.y)
                return abs(pin.frame.midX - expected.x) <= 2 && abs(pin.frame.midY - expected.y) <= 2
            }
        }
        let alignment = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: aligned, object: nil)], timeout: 6
        )
        attachFoldGeometry(stage, anchors: anchors)
        attachScreenshot(named: "Duo — \(stage) — repères")
        XCTAssertEqual(alignment, .completed,
                       "\(stage) : les repères doivent rester aux mêmes coordonnées dans leurs images, à 2 points près.")
        for identifier in ["comparisonMode", "addAnnotation", "zoomComparison"] {
            let control = element(identifier)
            XCTAssertTrue(control.exists && control.isHittable,
                          "\(stage) : la commande \(identifier) doit rester accessible au toucher.")
        }
        for anchor in anchors {
            let pin = element(anchor.pinIdentifier)
            XCTAssertTrue(pin.isHittable, "\(stage) : le repère doit rester accessible au toucher.")
            pin.tap()
            XCTAssertTrue(app.staticTexts[anchor.text].waitForExistence(timeout: 5),
                          "\(stage) : le texte exact de la note doit être conservé et relisible.")
            attachScreenshot(named: "Duo — \(stage) — \(anchor.pinIdentifier)")
            closeFoldCallout()
        }
    }

    private func attachFoldGeometry(_ stage: String, anchors: [FoldAnchor]) {
        func frameDictionary(_ frame: CGRect) -> [String: Double] {
            ["x": frame.minX, "y": frame.minY, "width": frame.width, "height": frame.height]
                .mapValues(Double.init)
        }
        let notes: [[String: Any]] = anchors.map { anchor in
            let pin = element(anchor.pinIdentifier)
            let image = element(anchor.imageIdentifier)
            let imageFrame = image.exists ? image.frame : .zero
            let pinFrame = pin.exists ? pin.frame : .zero
            let expected = CGPoint(x: imageFrame.minX + imageFrame.width * anchor.normalized.x,
                                   y: imageFrame.minY + imageFrame.height * anchor.normalized.y)
            return ["pin": anchor.pinIdentifier, "image": anchor.imageIdentifier, "text": anchor.text,
                    "pinExists": pin.exists, "pinHittable": pin.exists && pin.isHittable,
                    "imageExists": image.exists, "imageFrame": frameDictionary(imageFrame),
                    "pinFrame": frameDictionary(pinFrame),
                    "referenceX": Double(anchor.normalized.x), "referenceY": Double(anchor.normalized.y),
                    "deltaX": Double(pinFrame.midX - expected.x), "deltaY": Double(pinFrame.midY - expected.y)]
        }
        let controls: [[String: Any]] = ["comparisonMode", "addAnnotation", "zoomComparison"].map { identifier in
            let control = element(identifier)
            return ["identifier": identifier, "exists": control.exists,
                    "hittable": control.exists && control.isHittable,
                    "label": control.exists ? control.label : "",
                    "frame": frameDictionary(control.exists ? control.frame : .zero)]
        }
        let diagnostic: [String: Any] = [
            "stage": stage, "date": ISO8601DateFormatter().string(from: Date()),
            "window": frameDictionary(app.windows.firstMatch.frame),
            "canvas": frameDictionary(element("comparisonCanvas").frame), "anchors": notes,
            "controls": controls
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: diagnostic, options: [.prettyPrinted, .sortedKeys]),
              let description = String(data: data, encoding: .utf8) else { return }
        let attachment = XCTAttachment(string: description)
        attachment.name = "Duo — géométrie \(stage)"
        attachment.lifetime = .keepAlways
        add(attachment)
        foldLog("GEOMETRY \(stage) \(description.replacingOccurrences(of: "\n", with: " "))")
    }

    private func foldLog(_ message: String) {
        FileHandle.standardOutput.write(Data("[PARALLELE_FOLD] \(message)\n".utf8))
    }

    private var reviewExampleCard: XCUIElement {
        app.buttons.matching(NSPredicate(format: "label == %@", "Revue d’interface — Atelier")).firstMatch
    }

    private func createReviewExample() {
        let example = element("tryReviewExample")
        XCTAssertTrue(example.waitForExistence(timeout: 5))
        example.tap()
        XCTAssertTrue(element("comparisonCanvas").waitForExistence(timeout: 15),
                      "L’exemple embarqué doit créer puis ouvrir sa propre comparaison.")
        XCTAssertTrue(app.navigationBars["Revue d’interface — Atelier"].exists)
    }

    private func selectAnnotationFilter(_ title: String) {
        let filter = element("annotationFilter")
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        let choice = filter.buttons[title]
        XCTAssertTrue(choice.waitForExistence(timeout: 5), "Le filtre doit proposer \(title).")
        choice.tap()
    }

    private func assertReviewRows(_ visibleIndices: Set<Int>, file: StaticString = #filePath, line: UInt = #line) {
        let filter = element("annotationFilter")
        XCTAssertTrue(filter.waitForExistence(timeout: 5), file: file, line: line)
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5), file: file, line: line)
        var observedIndices = Set<Int>()
        // SwiftUI List only exposes materialized cells. Traverse this known
        // three-note fixture, including the rows below the compact viewport,
        // rather than treating an offscreen row as removed by the filter.
        for step in 0..<3 {
            let rows = list.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "annotationRow-"))
                .allElementsBoundByIndex
            for row in rows {
                if let index = Int(row.identifier.dropFirst("annotationRow-".count)) {
                    observedIndices.insert(index)
                }
            }
            if step < 2 { list.swipeUp() }
        }
        // Leave the filter and first row available for the next interaction.
        for _ in 0..<3 {
            if filter.isHittable { break }
            list.swipeDown()
        }
        XCTAssertTrue(filter.isHittable, file: file, line: line)
        XCTAssertEqual(observedIndices, visibleIndices,
                       "Le filtre doit afficher uniquement les repères \(visibleIndices.sorted()).",
                       file: file, line: line)
    }

    private func assertAnnotationStatus(_ title: String, file: StaticString = #filePath, line: UInt = #line) {
        let status = element("annotationStatus")
        let matches = NSPredicate(format: "exists == true AND label == %@", title)
        let result = XCTWaiter.wait(
            for: [XCTNSPredicateExpectation(predicate: matches, object: status)], timeout: 5
        )
        XCTAssertEqual(result, .completed, "Le repère sélectionné doit être \(title).", file: file, line: line)
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
