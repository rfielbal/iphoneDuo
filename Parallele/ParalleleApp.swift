import SwiftUI

@main
struct ParalleleApp: App {
    @State private var store = ParalleleApp.makeStore()
    @State private var selectedProject: ProjectSelection?

    var body: some Scene {
        WindowGroup {
            LibraryView { selectedProject = ProjectSelection(id: $0) }
                .environment(store)
                .fullScreenCover(item: $selectedProject) { selection in
                    if let project = store.project(id: selection.id) {
                        ComparisonEditor(project: project)
                            .environment(store)
                    }
                }
                .tint(.blue)
        }
    }

    private static func makeStore() -> ProjectStore {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Parallele-UITests")
            if ProcessInfo.processInfo.arguments.contains("--reset-test-library") {
                try? FileManager.default.removeItem(at: directory)
            }
            return ProjectStore(directory: directory)
        }
        #endif
        return ProjectStore()
    }
}

private struct ProjectSelection: Identifiable {
    let id: UUID
}
