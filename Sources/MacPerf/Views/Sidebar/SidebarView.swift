import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        List(selection: $appState.selectedCategory) {
            Section {
                SidebarMetricRow(category: .overview)
                    .tag(MetricCategory.overview)
            }

            Section("Hardware") {
                ForEach(MetricCategory.hardwareCategories.filter { $0 != .battery || appState.hasBattery }) { category in
                    SidebarMetricRow(category: category)
                        .tag(category)
                }
            }

            Section("System") {
                ForEach(MetricCategory.systemCategories) { category in
                    SidebarMetricRow(category: category)
                        .tag(category)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("MacPerf")
        .safeAreaInset(edge: .bottom) {
            Button {
                appState.selectedCategory = nil
                appState.showSettings = true
            } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(appState.showSettings ? themeManager.current.accent(for: .overview) : .secondary)
            .background(appState.showSettings ? themeManager.current.cardBackground : .clear)
        }
    }
}
