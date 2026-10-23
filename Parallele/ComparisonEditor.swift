import SwiftUI
import UIKit

struct ComparisonEditor: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var project: ComparisonProject
    @State private var pan: CGSize = .zero
    @State private var isPlacing = false
    @State private var editingNote: AnnotationDraft?
    @State private var selectedNote: ImageAnnotation?
    @State private var showNotes = false
    @State private var noteFilter: AnnotationStatus?
    @State private var error: String?
    @State private var exportItem: ExportItem?
    @State private var exporting = false
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let paired = project.mode == .sideBySide || (project.mode == .automatic && proxy.size.width >= 560)
                ZStack {
                    if let before = store.image(for: project, side: .before),
                       let after = store.image(for: project, side: .after) {
                        ComparisonCanvas(before: before, after: after, sideBySide: paired,
                                         split: $project.split, zoom: $project.zoom, pan: $pan,
                                         annotations: project.annotations, topInset: proxy.safeAreaInsets.top,
                                         trailingInset: proxy.safeAreaInsets.trailing, isPlacing: isPlacing,
                                         onPlace: placeAnnotation, onSelect: { selectedNote = $0 })
                            .ignoresSafeArea(.container)
                    } else {
                        ContentUnavailableView("Images indisponibles", systemImage: "photo.badge.exclamationmark",
                                               description: Text("L’une des images ne peut plus être lue. Le projet et ses notes sont conservés."))
                    }
                }
                .overlay(alignment: .top) {
                    if isPlacing {
                        Text("Touchez un détail pour ajouter un repère")
                            .font(.subheadline.weight(.medium)).multilineTextAlignment(.center)
                            .padding(14).glassEffect(in: Capsule())
                            .padding(.top, 56).padding(.horizontal, 20)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if let note = selectedNote {
                        noteCallout(note)
                            .frame(maxWidth: 300).padding(16).padding(.bottom, 88)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    controls(paired: paired)
                        .frame(width: controlsWidth(in: proxy, paired: paired))
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("comparisonControls")
                }
                .animation(reduceMotion ? nil : .smooth(duration: 0.28), value: paired)
            }
            .navigationTitle(project.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if persist() { dismiss() }
                    } label: { Label("Projets", systemImage: "chevron.left") }
                    .accessibilityIdentifier("backToLibrary")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNotes = true } label: {
                        Label("Revue", systemImage: "checklist")
                    }
                    .accessibilityLabel("Revue des annotations")
                    .accessibilityIdentifier("showAnnotations")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: export) {
                        Label("Exporter", systemImage: "square.and.arrow.up")
                    }
                    .disabled(exporting)
                    .accessibilityIdentifier("exportComparison")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            project.zoom = 1; pan = .zero; project.split = 0.5
                        } label: { Label("Réinitialiser la vue", systemImage: "arrow.counterclockwise") }
                        Divider()
                        Text("Enregistré sur cet appareil")
                    } label: { Label("Options", systemImage: "ellipsis") }
                }
            }
            .overlay {
                if exporting {
                    ProgressView("Préparation de la fiche…")
                        .padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                }
            }
        }
        .interactiveDismissDisabled()
        .onAppear { pan = CGSize(width: project.panX ?? 0, height: project.panY ?? 0) }
        .onChange(of: pan) { _, newValue in
            project.panX = newValue.width
            project.panY = newValue.height
        }
        .onChange(of: project) { _, _ in
            saveTask?.cancel()
            saveTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                _ = persist()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { saveTask?.cancel(); _ = persist() }
        }
        .onDisappear { saveTask?.cancel(); _ = persist() }
        .sheet(item: $editingNote) { draft in
            AnnotationForm(draft: draft) { updated in
                if let index = project.annotations.firstIndex(where: { $0.id == updated.id }) {
                    project.annotations[index] = updated
                } else {
                    project.annotations.append(updated)
                }
                selectedNote = updated
                isPlacing = false
                _ = persist()
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showNotes) {
            notesList
                .presentationDetents([.large])
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Action impossible", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
    }

    private func controlsWidth(in proxy: GeometryProxy, paired: Bool) -> CGFloat {
        if #available(iOS 27.1, *) {
            let bounds = CGRect(origin: .zero, size: proxy.size)
            if let division = proxy.reservedRegions(kind: .division).first(where: {
                $0.isActive && $0.frame.height > $0.frame.width && $0.frame.intersects(bounds)
            }) {
                // Keep the entire dock in the trailing pane. The geometry is
                // already inside the system bars' safe area; the reserved region
                // supplies the additional clearance needed around the hinge.
                let start = max(0, division.frame.maxX + division.margins.trailing)
                let available = proxy.size.width - start
                if available > 0 { return available }
            }
        }
        // A horizontal fold leaves the bottom dock inside the lower pane.
        // With no active fold, use the right pane only for a horizontal split.
        // Compact and vertically arranged presentations retain their centering.
        if paired && proxy.size.width > proxy.size.height {
            return proxy.size.width / 2
        }
        return proxy.size.width
    }

    private func controls(paired: Bool) -> some View {
        GlassEffectContainer(spacing: 14) {
            HStack(spacing: 12) {
                Menu {
                    Button { project.mode = .automatic } label: { Label("Automatique", systemImage: "rectangle.2.swap") }
                    Button { project.mode = .swipe } label: { Label("Balayage", systemImage: "slider.horizontal.below.rectangle") }
                    Button { project.mode = .sideBySide } label: { Label("Côte à côte", systemImage: "rectangle.split.2x1") }
                } label: {
                    Label(project.mode == .automatic ? "Auto" : (paired ? "Côte à côte" : "Balayage"),
                          systemImage: paired ? "rectangle.split.2x1" : "slider.horizontal.below.rectangle")
                        .font(.subheadline.weight(.semibold)).padding(.horizontal, 18).frame(height: 50)
                }
                .glassEffect(.regular.interactive(), in: Capsule())
                .accessibilityIdentifier("comparisonMode")

                Button {
                    isPlacing.toggle(); selectedNote = nil
                    if isPlacing { project.zoom = 1; pan = .zero }
                } label: {
                    Image(systemName: isPlacing ? "xmark" : "plus.bubble")
                        .font(.system(size: 20, weight: .medium)).frame(width: 50, height: 50)
                }
                .glassEffect(.regular.tint(isPlacing ? .blue.opacity(0.2) : nil).interactive(), in: Circle())
                .accessibilityLabel(isPlacing ? "Annuler le repère" : "Ajouter une annotation")
                .accessibilityIdentifier("addAnnotation")

                Button {
                    project.zoom = project.zoom > 1 ? 1 : 2
                    pan = .zero
                } label: {
                    Text("\(project.zoom, specifier: "%.1f")×")
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .monospacedDigit().frame(width: 54, height: 50)
                }
                .glassEffect(.regular.interactive(), in: Capsule())
                .accessibilityLabel("Zoom \(project.zoom, specifier: "%.1f") fois. Réinitialiser ou agrandir.")
                .accessibilityIdentifier("zoomComparison")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 12)
    }

    private func noteCallout(_ note: ImageAnnotation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Repère \((project.annotations.firstIndex(where: { $0.id == note.id }) ?? 0) + 1)", systemImage: "mappin.circle.fill")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.blue)
                Spacer()
                Button { selectedNote = nil } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                    .accessibilityLabel("Fermer le repère")
            }
            Label(note.status.title, systemImage: note.status.systemImage)
                .font(.caption.weight(.medium))
                .foregroundStyle(note.status == .validated ? Color.green : Color.secondary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(note.status.title)
                .accessibilityIdentifier("annotationStatus")
            Text(note.text).font(.subheadline).lineLimit(5)
            HStack {
                Button { toggleStatus(note) } label: {
                    Label(note.status == .validated ? "Rouvrir" : "Valider",
                          systemImage: note.status == .validated ? "arrow.uturn.backward" : "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(note.status == .validated ? "Remettre à corriger" : "Marquer comme validé")
                .accessibilityIdentifier("toggleAnnotationStatus")
                Button("Modifier") { editingNote = AnnotationDraft(note: note) }
                    .buttonStyle(.bordered)
            }
            .font(.subheadline.weight(.medium))
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 15, y: 6)
    }

    private var notesList: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(reviewSummary)
                            .font(.headline)
                            .accessibilityIdentifier("annotationReviewSummary")
                        if !project.annotations.isEmpty {
                            ProgressView(value: Double(project.validatedAnnotationCount),
                                         total: Double(project.annotations.count))
                                .tint(.green)
                                .accessibilityLabel("Avancement de la revue")
                                .accessibilityValue("\(project.validatedAnnotationCount) sur \(project.annotations.count) observations validées")
                        }
                        Picker("Afficher", selection: $noteFilter) {
                            Text("Toutes").tag(AnnotationStatus?.none)
                            Text("À corriger").tag(AnnotationStatus?.some(.toReview))
                            Text("Validé").tag(AnnotationStatus?.some(.validated))
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("annotationFilter")
                    }
                    .padding(.vertical, 6)
                }
                if project.annotations.isEmpty {
                    ContentUnavailableView("Aucun repère", systemImage: "text.bubble",
                                           description: Text("Ajoutez un repère en touchant un détail de l’image."))
                } else if filteredNotes.isEmpty {
                    ContentUnavailableView(noteFilter == .validated ? "Aucune observation validée" : "Tout est validé",
                                           systemImage: noteFilter == .validated ? "checkmark.circle" : "checkmark.circle.fill",
                                           description: Text(noteFilter == .validated ? "Validez un repère après avoir vérifié ce détail." : "Il ne reste aucune observation à corriger."))
                        .accessibilityIdentifier("emptyAnnotationFilter")
                }
                ForEach(filteredNotes, id: \.element.id) { index, note in
                    Button {
                        showNotes = false
                        reveal(note)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)").fontWeight(.bold)
                                .foregroundStyle(note.status == .validated ? Color.green : Color.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.text).foregroundStyle(.primary)
                                Label("\(note.side == .before ? "Original" : "Retouche") · \(note.status.title)",
                                      systemImage: note.status.systemImage)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("annotationRow-\(index)")
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button { toggleStatus(note) } label: {
                            Label(note.status == .validated ? "Rouvrir" : "Valider",
                                  systemImage: note.status == .validated ? "arrow.uturn.backward" : "checkmark")
                        }
                        .tint(note.status == .validated ? .gray : .green)
                    }
                    .swipeActions {
                        Button("Supprimer", role: .destructive) {
                            project.annotations.removeAll { $0.id == note.id }
                            if selectedNote?.id == note.id { selectedNote = nil }
                            _ = persist()
                        }
                    }
                }
            }
            .navigationTitle("Revue").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { showNotes = false } label: { Label("Terminé", systemImage: "checkmark") }
                        .accessibilityIdentifier("closeAnnotations")
                }
            }
        }
    }

    private var filteredNotes: [(offset: Int, element: ImageAnnotation)] {
        Array(project.annotations.enumerated()).filter { noteFilter == nil || $0.element.status == noteFilter }
    }

    private var reviewSummary: String {
        let validated = project.validatedAnnotationCount
        return "\(project.pendingAnnotationCount) à corriger · \(validated) validé\(validated > 1 ? "s" : "")"
    }

    private func toggleStatus(_ note: ImageAnnotation) {
        guard let index = project.annotations.firstIndex(where: { $0.id == note.id }) else { return }
        project.annotations[index].status = note.status == .validated ? .toReview : .validated
        if selectedNote?.id == note.id { selectedNote = project.annotations[index] }
        _ = persist()
    }

    private func reveal(_ note: ImageAnnotation) {
        // A review row must lead back to a visible point even if the user had
        // zoomed elsewhere or hidden this image behind the swipe divider.
        project.zoom = 1
        pan = .zero
        if (note.side == .before && note.x >= 0.98) || (note.side == .after && note.x <= 0.02) {
            // The divider keeps a small drag margin. Use both images when that
            // margin would hide a point at the outer edge of its image.
            project.mode = .sideBySide
        }
        project.split = note.side == .before ? min(0.98, max(0.5, note.x + 0.08)) : max(0.02, min(0.5, note.x - 0.08))
        isPlacing = false
        selectedNote = note
    }

    private func placeAnnotation(side: ImageSide, point: CGPoint) {
        editingNote = AnnotationDraft(note: ImageAnnotation(x: point.x, y: point.y, text: "", side: side))
    }

    @discardableResult private func persist() -> Bool {
        do { try store.update(project); return true }
        catch { self.error = "La modification n’a pas pu être sauvegardée : \(error.localizedDescription)"; return false }
    }

    private func export() {
        guard persist(), let before = store.image(for: project, side: .before),
              let after = store.image(for: project, side: .after) else { return }
        exporting = true
        Task { @MainActor in
            await Task.yield()
            do {
                let saved = store.project(id: project.id) ?? project
                let url = try ComparisonExporter.export(project: saved, before: before, after: after)
                exportItem = ExportItem(url: url)
            } catch { self.error = error.localizedDescription }
            exporting = false
        }
    }
}

private struct AnnotationDraft: Identifiable {
    let note: ImageAnnotation
    var id: UUID { note.id }
}

private struct AnnotationForm: View {
    @Environment(\.dismiss) private var dismiss
    let draft: AnnotationDraft
    let onSave: (ImageAnnotation) -> Void
    @State private var text: String
    @State private var status: AnnotationStatus
    @FocusState private var focused: Bool

    init(draft: AnnotationDraft, onSave: @escaping (ImageAnnotation) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _text = State(initialValue: draft.note.text)
        _status = State(initialValue: draft.note.status)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Votre observation") {
                    TextField("Qu’est-ce qui change ici ?", text: $text, axis: .vertical)
                        .lineLimit(4...8).focused($focused).accessibilityIdentifier("annotationText")
                        .onChange(of: text) { _, newValue in if newValue.count > 500 { text = String(newValue.prefix(500)) } }
                }
                Section("État de la revue") {
                    Picker("État", selection: $status) {
                        ForEach(AnnotationStatus.allCases) { value in
                            Label(value.title, systemImage: value.systemImage).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("annotationStatusPicker")
                }
                Section { Text("Le repère reste attaché à ce détail quand la fenêtre change de taille.").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("Annotation").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Label("Annuler", systemImage: "xmark") }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        var note = draft.note
                        note.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        note.status = status
                        onSave(note); dismiss()
                    } label: { Label("Enregistrer", systemImage: "checkmark") }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("saveAnnotation")
                }
            }
            .task { focused = true }
        }
    }
}

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.view.accessibilityIdentifier = "exportShareSheet"
        return controller
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
