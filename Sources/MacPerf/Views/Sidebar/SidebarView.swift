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
                ForEach(MetricCategory.hardwareCategories) { category in
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
    }
}
