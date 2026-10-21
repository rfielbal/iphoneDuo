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
                .overlay(alignment: .bottom) { controls(paired: paired) }
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
                    Button(action: export) {
                        Label("Exporter", systemImage: "square.and.arrow.up")
                    }
                    .disabled(exporting)
                    .accessibilityIdentifier("exportComparison")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { showNotes = true } label: {
                            Label("Annotations (\(project.annotations.count))", systemImage: "text.bubble")
                        }
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
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Action impossible", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("OK", role: .cancel) { error = nil }
        } message: { Text(error ?? "") }
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
            Text(note.text).font(.subheadline).lineLimit(5)
            Button("Modifier") { editingNote = AnnotationDraft(note: note) }
                .font(.subheadline.weight(.medium))
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.06), radius: 15, y: 6)
    }

    private var notesList: some View {
        NavigationStack {
            List {
                if project.annotations.isEmpty {
                    ContentUnavailableView("Aucun repère", systemImage: "text.bubble",
                                           description: Text("Ajoutez un repère en touchant un détail de l’image."))
                }
                ForEach(Array(project.annotations.enumerated()), id: \.element.id) { index, note in
                    Button {
                        showNotes = false
                        selectedNote = note
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)").fontWeight(.bold).foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.text).foregroundStyle(.primary)
                                Text(note.side == .before ? "Original" : "Retouche").font(.caption).foregroundStyle(.secondary)
                            }
                        }
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
            .navigationTitle("Annotations").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { showNotes = false } label: { Label("Terminé", systemImage: "checkmark") }
                }
            }
        }
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
    @FocusState private var focused: Bool

    init(draft: AnnotationDraft, onSave: @escaping (ImageAnnotation) -> Void) {
        self.draft = draft
        self.onSave = onSave
        _text = State(initialValue: draft.note.text)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Votre observation") {
                    TextField("Qu’est-ce qui change ici ?", text: $text, axis: .vertical)
                        .lineLimit(4...8).focused($focused).accessibilityIdentifier("annotationText")
                        .onChange(of: text) { _, newValue in if newValue.count > 500 { text = String(newValue.prefix(500)) } }
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
