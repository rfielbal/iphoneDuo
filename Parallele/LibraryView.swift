import SwiftUI
import PhotosUI
import ImageIO

/// The local library is intentionally native: system navigation and search,
/// photographic cards, and a Photos picker that grants access only to selections.
struct LibraryView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let onOpen: (UUID) -> Void

    @State private var search = ""
    @State private var showingImport = false
    @State private var createdProjectID: UUID?
    @State private var showingAbout = false
    @State private var renameID: UUID?
    @State private var renameTitle = ""
    @State private var showingRename = false
    @State private var pendingDeletion: ComparisonProject?
    @State private var showingDeletion = false
    @State private var creatingExample = false

    private var matchingProjects: [ComparisonProject] {
        store.projects
            .filter {
                search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || $0.title.localizedStandardContains(search)
            }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 280 : 300,
                            maximum: 560), spacing: 24, alignment: .top)]
    }

    var body: some View {
        NavigationStack {
            libraryContent
                .navigationTitle("Parallèle")
                .searchable(text: $search, prompt: "Rechercher une comparaison")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            showingAbout = true
                        } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel("À propos de Parallèle")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingImport = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Nouvelle comparaison")
                        .accessibilityIdentifier("newComparison")
                    }
                }
                .sheet(isPresented: $showingImport, onDismiss: {
                    guard let id = createdProjectID else { return }
                    createdProjectID = nil
                    onOpen(id)
                }) {
                    ImportComparisonView { id in
                        createdProjectID = id
                        showingImport = false
                    }
                }
                .sheet(isPresented: $showingAbout) {
                    LibraryAboutView()
                }
                .alert("Renommer la comparaison", isPresented: $showingRename) {
                    TextField("Titre", text: $renameTitle)
                        .textInputAutocapitalization(.sentences)
                    Button("Annuler", role: .cancel) { renameID = nil }
                    Button("Enregistrer") { renameProject() }
                        .disabled(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .confirmationDialog(
                    "Supprimer cette comparaison ?",
                    isPresented: $showingDeletion,
                    titleVisibility: .visible
                ) {
                    Button("Supprimer la comparaison", role: .destructive) {
                        guard let project = pendingDeletion else { return }
                        do { try store.delete(id: project.id) }
                        catch { store.errorMessage = error.localizedDescription }
                        pendingDeletion = nil
                    }
                    Button("Annuler", role: .cancel) { pendingDeletion = nil }
                } message: {
                    Text("La comparaison et ses annotations seront supprimées de Parallèle. Les images de votre photothèque seront conservées.")
                }
                .alert(
                    "Impossible de terminer",
                    isPresented: Binding(
                        get: { store.errorMessage != nil },
                        set: { if !$0 { store.errorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { store.errorMessage = nil }
                } message: {
                    Text(store.errorMessage ?? "")
                }
        }
    }

    @ViewBuilder private var libraryContent: some View {
        if store.projects.isEmpty {
            ContentUnavailableView {
                Label("Deux images. Un autre regard.", systemImage: "rectangle.on.rectangle")
            } description: {
                Text("Comparez deux versions d’une image ou d’une interface, puis suivez vos observations.")
            } actions: {
                Button("Créer une comparaison") { showingImport = true }
                    .buttonStyle(.glassProminent)
                reviewExampleButton
            }
        } else if matchingProjects.isEmpty {
            ContentUnavailableView.search(text: search)
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        reviewExampleButton
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text("Votre regard, côte à côte.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 12)
                        Text("\(matchingProjects.count)")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.tertiary)
                            .accessibilityLabel(
                                matchingProjects.count == 1
                                    ? "1 comparaison"
                                    : "\(matchingProjects.count) comparaisons"
                            )
                    }
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 28) {
                        ForEach(matchingProjects) { project in
                            projectCard(project)
                        }
                    }
                    Label("Enregistré sur cet appareil", systemImage: "internaldrive")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, horizontalSizeClass == .compact ? 20 : 32)
                .padding(.top, 12)
                .frame(maxWidth: 1440)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func projectCard(_ project: ComparisonProject) -> some View {
        Button {
            onOpen(project.id)
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                GeometryReader { geometry in
                    HStack(spacing: 2) {
                        cardImage(store.image(for: project, side: .before), letter: "A")
                            .frame(width: (geometry.size.width - 2) / 2)
                        cardImage(store.image(for: project, side: .after), letter: "B")
                            .frame(width: (geometry.size.width - 2) / 2)
                    }
                }
                .aspectRatio(1.55, contentMode: .fit)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.primary.opacity(0.06), lineWidth: 0.5)
                }
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text(project.updatedAt, format: .dateTime.day().month(.wide))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    if !project.annotations.isEmpty {
                        Label(project.pendingAnnotationCount == 0 ? "Revue validée" : "\(project.pendingAnnotationCount) à corriger",
                              systemImage: project.pendingAnnotationCount == 0 ? "checkmark.circle.fill" : "checklist")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(project.pendingAnnotationCount == 0 ? Color.green : Color.secondary)
                            .padding(.top, 3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 2)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(project.title)
        .accessibilityValue("\(project.annotations.count) annotations, \(project.pendingAnnotationCount) à corriger, \(project.validatedAnnotationCount) validées")
        .accessibilityHint("Ouvre la comparaison. Des actions supplémentaires sont disponibles.")
        .accessibilityIdentifier(project.id == matchingProjects.first?.id ? "demoProject" : "projectCard-\(project.id.uuidString)")
        .contextMenu {
            Button("Ouvrir", systemImage: "arrow.up.forward.app") { onOpen(project.id) }
            Button("Renommer", systemImage: "pencil") {
                renameID = project.id
                renameTitle = project.title
                showingRename = true
            }
            Button("Dupliquer", systemImage: "plus.square.on.square") {
                do { _ = try store.duplicate(id: project.id) }
                catch { store.errorMessage = error.localizedDescription }
            }
            Divider()
            Button("Supprimer", systemImage: "trash", role: .destructive) {
                pendingDeletion = project
                showingDeletion = true
            }
        }
    }

    private var reviewExampleButton: some View {
        Button(action: createReviewExample) {
            HStack(spacing: 14) {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.title2).foregroundStyle(.blue)
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Essayer une revue").font(.headline).foregroundStyle(.primary)
                    Text("Une interface fictive, trois observations à explorer.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if creatingExample {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.right").font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }
            }
            .padding(18)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.primary.opacity(0.06), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(creatingExample)
        .accessibilityIdentifier("tryReviewExample")
        .accessibilityHint("Crée une comparaison d’exemple indépendante et ouvre ses trois observations.")
    }

    private func createReviewExample() {
        guard !creatingExample else { return }
        creatingExample = true
        Task { @MainActor in
            defer { creatingExample = false }
            await Task.yield()
            do {
                let project = try store.createReviewExample()
                onOpen(project.id)
            } catch { store.errorMessage = error.localizedDescription }
        }
    }

    private func cardImage(_ image: UIImage?, letter: String) -> some View {
        GeometryReader { geometry in
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(.quaternary)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
            }
            .overlay(alignment: .bottomLeading) {
                Text(letter)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.32), in: Capsule())
                    .padding(12)
            }
        }
        .accessibilityHidden(true)
    }

    private func renameProject() {
        defer { renameID = nil }
        guard let id = renameID, var project = store.project(id: id) else { return }
        let title = renameTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        project.title = String(title.prefix(120))
        project.updatedAt = .now
        do { try store.update(project) }
        catch { store.errorMessage = error.localizedDescription }
    }
}

private struct ImportComparisonView: View {
    @Environment(ProjectStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let onCreated: (UUID) -> Void

    @State private var title = ""
    @State private var beforeSelection: PhotosPickerItem?
    @State private var afterSelection: PhotosPickerItem?
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    @State private var loadingBefore = false
    @State private var loadingAfter = false
    @State private var beforeLoadID = UUID()
    @State private var afterLoadID = UUID()
    @State private var creating = false
    @State private var errorMessage: String?
    @FocusState private var titleIsFocused: Bool

    private var isReady: Bool {
        beforeImage != nil && afterImage != nil
            && !loadingBefore && !loadingAfter && !creating
            && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Text("Choisissez deux versions d’une même image.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .top, spacing: 14) {
                        PhotosPicker(selection: $beforeSelection, matching: .images,
                                     preferredItemEncoding: .compatible) {
                            ImportPhotoSlot(
                                title: "Original", letter: "A", image: beforeImage,
                                isLoading: loadingBefore
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(creating)
                        .accessibilityLabel(beforeImage == nil ? "Choisir l’original" : "Remplacer l’original")
                        .accessibilityIdentifier("pickOriginal")

                        PhotosPicker(selection: $afterSelection, matching: .images,
                                     preferredItemEncoding: .compatible) {
                            ImportPhotoSlot(
                                title: "Retouche", letter: "B", image: afterImage,
                                isLoading: loadingAfter
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(creating)
                        .accessibilityLabel(afterImage == nil ? "Choisir la retouche" : "Remplacer la retouche")
                        .accessibilityIdentifier("pickRetouch")
                    }

                    if beforeImage != nil || afterImage != nil {
                        Button("Intervertir les images", systemImage: "arrow.left.arrow.right") {
                            swap(&beforeImage, &afterImage)
                            beforeSelection = nil
                            afterSelection = nil
                        }
                        .font(.subheadline)
                        .buttonStyle(.glass)
                        .disabled(loadingBefore || loadingAfter || creating)
                        .frame(maxWidth: .infinity)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Titre")
                            .font(.subheadline.weight(.semibold))
                        TextField("Ex. Lumière de fin de journée", text: $title)
                            .textInputAutocapitalization(.sentences)
                            .submitLabel(.done)
                            .focused($titleIsFocused)
                            .onSubmit { titleIsFocused = false }
                            .padding(15)
                            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 14))
                            .accessibilityIdentifier("projectTitle")
                            .onChange(of: title) { _, value in
                                if value.count > 120 { title = String(value.prefix(120)) }
                            }
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("importError")
                    }

                    Button {
                        createComparison()
                    } label: {
                        HStack(spacing: 10) {
                            if creating { ProgressView().tint(.white) }
                            Text(creating ? "Création…" : "Créer la comparaison")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .disabled(!isReady)
                    .accessibilityIdentifier("createComparison")

                    Label {
                        Text("Seules les images choisies sont importées. Vos originaux restent intacts dans Photos.")
                    } icon: {
                        Image(systemName: "lock")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(24)
                .frame(maxWidth: 650)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .accessibilityIdentifier("importScrollView")
            .navigationTitle("Nouvelle comparaison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        titleIsFocused = false
                        dismiss()
                    } label: {
                        Label("Annuler", systemImage: "xmark")
                    }
                        .disabled(creating)
                        .accessibilityLabel("Annuler l’import")
                        .accessibilityIdentifier("cancelImport")
                }
            }
            .interactiveDismissDisabled(creating)
            .onChange(of: beforeSelection) { _, item in
                guard let item else { return }
                Task { await loadImage(item, isBefore: true) }
            }
            .onChange(of: afterSelection) { _, item in
                guard let item else { return }
                Task { await loadImage(item, isBefore: false) }
            }
        }
    }

    @MainActor private func loadImage(_ item: PhotosPickerItem, isBefore: Bool) async {
        let loadID = UUID()
        if isBefore {
            beforeLoadID = loadID
            loadingBefore = true
        } else {
            afterLoadID = loadID
            loadingAfter = true
        }
        errorMessage = nil
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw PhotoImportError.unreadable
            }
            // Decode a bounded-size image away from the main actor. This also
            // resolves EXIF orientation before the comparison renderer sees it.
            let image = try await Task.detached(priority: .userInitiated) {
                try PhotoImportDecoder.decode(data)
            }.value
            guard (isBefore ? beforeLoadID : afterLoadID) == loadID else { return }
            if isBefore { beforeImage = image } else { afterImage = image }
        } catch {
            guard (isBefore ? beforeLoadID : afterLoadID) == loadID else { return }
            errorMessage = "L’image n’a pas pu être importée. Si elle est dans iCloud, vérifiez votre connexion puis réessayez."
        }
        guard (isBefore ? beforeLoadID : afterLoadID) == loadID else { return }
        if isBefore { loadingBefore = false } else { loadingAfter = false }
    }

    private func createComparison() {
        guard isReady, let beforeImage, let afterImage else { return }
        creating = true
        errorMessage = nil
        titleIsFocused = false
        Task { @MainActor in
            await Task.yield()
            do {
                let id = try store.create(
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    before: beforeImage,
                    after: afterImage
                )
                onCreated(id)
            } catch {
                errorMessage = error.localizedDescription
                creating = false
            }
        }
    }
}

private struct ImportPhotoSlot: View {
    let title: String
    let letter: String
    let image: UIImage?
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
                if let image {
                    GeometryReader { geometry in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 28, weight: .light))
                        Text("Choisir")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }
                if isLoading {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    ProgressView("Chargement…")
                        .font(.caption)
                }
            }
            .aspectRatio(0.85, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .topLeading) {
                Text(letter)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .glassEffect(in: Capsule())
                    .padding(12)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.leading, 4)
        }
        .frame(maxWidth: .infinity)
    }
}

private enum PhotoImportError: LocalizedError {
    case unreadable
    var errorDescription: String? { "Cette image ne peut pas être lue." }
}

private enum PhotoImportDecoder {
    static func decode(_ data: Data) throws -> UIImage {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else { throw PhotoImportError.unreadable }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 4096,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw PhotoImportError.unreadable
        }
        return UIImage(cgImage: image)
    }
}

private struct LibraryAboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.largeTitle.weight(.light))
                            .foregroundStyle(.tint)
                        Text("Parallèle")
                            .font(.title2.weight(.semibold))
                        Text("Deux images, un même regard. Comparez une évolution et gardez une trace de vos observations.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                }
                Section("Vos images") {
                    Label("Import limité aux photos sélectionnées", systemImage: "photo")
                    Label("Comparaisons enregistrées sur cet appareil", systemImage: "internaldrive")
                    Label("Aucun compte requis", systemImage: "person.crop.circle.badge.checkmark")
                    Text("Les photos originales ne sont jamais modifiées. Les copies enregistrées sont adaptées à une définition maximale de 2 500 pixels pour conserver une navigation fluide.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Pour commencer") {
                    Text("Ouvrez la comparaison de démonstration ou importez un original et une retouche. Explorez les différences, puis ajoutez vos annotations.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("À propos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: {
                        Label("Terminé", systemImage: "checkmark")
                    }
                    .accessibilityLabel("Fermer À propos")
                    .accessibilityIdentifier("closeAbout")
                }
            }
        }
    }
}
