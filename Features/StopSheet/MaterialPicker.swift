import SwiftUI

/// What the work was on: zweef.app's material list, in the same three tabs as
/// zweef.app's own maintenance form — flying, rolling, other (ADR 0020).
///
/// A sheet of its own rather than rows on the stop sheet, because a club has
/// a dozen aircraft or more, and a member who remembers "the Discus" but not
/// its registration needs to type. Search looks through every tab at once.
///
/// Glass tiles, like the member tiles on the home screen: these are buttons
/// (ADR 0014).
struct MaterialPicker: View {
    @Environment(\.metrics) private var metrics
    @Environment(\.dismiss) private var dismiss

    let material: [Material]
    let selected: Material?
    var onSelect: (Material?) -> Void

    @State private var kind: MaterialKind
    @State private var searchText = ""

    init(material: [Material], selected: Material?, onSelect: @escaping (Material?) -> Void) {
        self.material = material
        self.selected = selected
        self.onSelect = onSelect
        // Open on the tab of what was picked, else the first one with
        // anything in it.
        let firstFilled = MaterialKind.allCases.first { kind in material.contains { $0.kind == kind } }
        self._kind = State(initialValue: selected?.kind ?? firstFilled ?? .flying)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: metrics.sectionSpacing) {
                    if searchText.isEmpty, availableKinds.count > 1 {
                        Picker("Kind", selection: $kind) {
                            ForEach(availableKinds, id: \.self) { kind in
                                Text(kind.title).tag(kind)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    if matches.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 10)], spacing: 10) {
                            ForEach(matches) { item in
                                tile(item)
                            }
                        }
                    }
                }
                .padding(metrics.gutter)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("What did you work on?")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("Name or type"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") { dismiss() }
                        .labelStyle(.iconOnly)
                }
                if selected != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Picking is optional, so taking it back out has to be
                        // possible too.
                        Button("Nothing") {
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

    private func tile(_ item: Material) -> some View {
        let isSelected = selected?.zweefId == item.zweefId
        return Button {
            onSelect(item)
            dismiss()
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    // Always a second line, so the tiles stay one height.
                    Text(item.displayType ?? " ")
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

    /// The tabs that have anything in them, in zweef.app's order.
    private var availableKinds: [MaterialKind] {
        MaterialKind.allCases.filter { kind in material.contains { $0.kind == kind } }
    }

    /// One tab, or — while searching — every tab, on the name and the type,
    /// ignoring case and accents.
    private var matches: [Material] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            return material.filter { $0.kind == kind }.sortedForPicker()
        }
        return material
            .filter { $0.name.localizedStandardContains(query) || ($0.displayType?.localizedStandardContains(query) ?? false) }
            .sortedForPicker()
    }
}

extension MaterialKind {
    /// zweef.app's own tab names, translated: "Vliegend", "Rollend", "Overig".
    var title: LocalizedStringKey {
        switch self {
        case .flying: "Flying"
        case .rolling: "Rolling"
        case .other: "Other"
        }
    }
}

#if DEBUG
#Preview {
    Color.clear.sheet(isPresented: .constant(true)) {
        MaterialPicker(
            material: SampleData.material.map {
                Material(zweefId: $0.id, name: $0.name, kind: $0.kind, typeName: $0.type, isGlider: $0.isGlider)
            },
            selected: nil
        ) { _ in }
    }
}
#endif
