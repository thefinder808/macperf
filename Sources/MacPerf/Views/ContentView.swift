import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
                SidebarView()
                    .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
            } detail: {
                Group {
                    if appState.showSettings {
                        SettingsView()
                    } else {
                        detailView
                            .id(appState.selectedCategory)
                            .transition(.opacity.combined(with: .offset(y: 8)))
                            .animation(.easeInOut(duration: 0.2), value: appState.selectedCategory)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(themeManager.current.windowBackground)
            }
            .navigationSplitViewStyle(.prominentDetail)

            // Command palette overlay
            if appState.showCommandPalette {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            appState.showCommandPalette = false
                        }
                    }
                    .transition(.opacity)

                VStack {
                    CommandPalette()
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                        .padding(.top, 80)
                    Spacer()
                }
            }
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.9), value: appState.showCommandPalette)
        .frame(minWidth: 900, minHeight: 550)
        .background(WindowAccessor())
        .onChange(of: appState.selectedCategory) {
            appState.showSettings = false
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch appState.selectedCategory {
        case .overview:
            OverviewView()
        case .cpu:
            CPUDetailView()
        case .memory:
            MemoryDetailView()
        case .disk:
            DiskDetailView()
        case .network:
            NetworkDetailView()
        case .gpu:
            GPUDetailView()
        case .thermal:
            ThermalDetailView()
        case .battery:
            BatteryDetailView()
        case .processes:
            ProcessDetailView()
        case .storage:
            StorageDetailView()
        }
    }
}
