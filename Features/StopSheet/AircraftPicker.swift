import SwiftUI

/// Picks the aircraft the work was on: a searchable grid of glass tiles, in a
/// form sheet the size of the stop sheet it opens from.
///
/// A sheet of its own rather than rows under the task, because a club can have
/// a dozen aircraft or more, and a member who remembers "the Discus" but not
/// its registration needs to type. Each tile shows the registration large and
/// the type underneath; search matches either.
///
/// Glass, like the member tiles on the home screen: these are buttons, and
/// they should look like the other things on the device that you tap
/// (ADR 0014).
struct AircraftPicker: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.dismiss) private var dismiss

    let aircraft: [Aircraft]
    let selected: Aircraft?
    var onSelect: (Aircraft?) -> Void

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                if matches.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                        .padding(.top, 40)
                } else {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(matches) { plane in
                            tile(plane)
                        }
                    }
                    .padding(metrics.gutter)
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Aircraft")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("Registration or type"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                if selected != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        // The aircraft is optional, so taking it back out has
                        // to be possible too.
                        Button("No aircraft") {
                            onSelect(nil)
                            dismiss()
                        }
                    }
                }
            }
        }
        .presentationSizing(.form)
        .resolvedLayoutMetrics()
    }

    private func tile(_ plane: Aircraft) -> some View {
        let isSelected = selected?.zweefId == plane.zweefId
        return Button {
            onSelect(plane)
            dismiss()
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plane.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    // Always a second line, so the tiles stay one height.
                    Text(plane.displayType ?? " ")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tint)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: metrics.tileHeight, alignment: .leading)
            .contentShape(.rect(cornerRadius: metrics.tileCornerRadius))
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: metrics.tileCornerRadius))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// Gliders first — most workshop hours go into them — then the rest, each
    /// alphabetically; filtered on the registration and the type, ignoring
    /// case and accents.
    private var matches: [Aircraft] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return aircraft
            .filter { plane in
                query.isEmpty
                    || plane.name.localizedStandardContains(query)
                    || (plane.displayType?.localizedStandardContains(query) ?? false)
            }
            .sorted { lhs, rhs in
                if lhs.isGlider != rhs.isGlider { return lhs.isGlider }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
    }
}

extension Aircraft {
    /// The type to show, or nil when zweef.app has none for it. An empty
    /// stored type means "fetched, and there is none"; nil means "not fetched
    /// yet" (see `SyncEngine.upsert(material:in:)`).
    var displayType: String? {
        guard let typeName, !typeName.isEmpty else { return nil }
        return typeName
    }
}

#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        AircraftPicker(
            aircraft: SampleData.aircraft.map { Aircraft(zweefId: $0.id, name: $0.name, typeName: $0.type) },
            selected: nil
        ) { _ in }
    }
}
