import FamilyControls
import SwiftUI

struct AddBlockerView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var minutes = 10
    @State private var selection = FamilyActivitySelection()

    var onSave: (String, Int, FamilyActivitySelection) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("z. B. Instagram", text: $title)
                }

                Section {
                    Stepper("\(minutes) Minuten", value: $minutes, in: 1...240)
                } header: {
                    Text("Zeit pro Runde")
                } footer: {
                    Text("Nach dieser Nutzungszeit erscheint die Sperre und du musst Liegestütze machen, bevor es weitergeht.")
                }

                Section("Apps, Kategorien oder Webseiten") {
                    FamilyActivityPicker(selection: $selection)
                        .frame(minHeight: 340)
                }
            }
            .navigationTitle("Neue Sperre")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        onSave(title, minutes, selection)
                        dismiss()
                    }
                    .disabled(!hasSelection)
                }
            }
        }
    }

    private var hasSelection: Bool {
        !selection.applicationTokens.isEmpty
            || !selection.categoryTokens.isEmpty
            || !selection.webDomainTokens.isEmpty
    }
}
