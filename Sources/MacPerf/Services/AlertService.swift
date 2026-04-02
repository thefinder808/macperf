import Foundation
import UserNotifications

final class AlertService {
    struct AlertConfig {
        var cpuThreshold: Double = 90        // % sustained
        var cpuSustainSeconds: Int = 30
        var memoryPressureAlert: Bool = true  // warn on Warning/Critical
        var thermalAlert: Bool = true         // warn on Serious/Critical
        var diskSpaceThreshold: Double = 10   // % free remaining
        var enabled: Bool = true
    }

    var config = AlertConfig()

    private var cpuHighStart: Date?
    private var lastMemoryAlert: Date?
    private var lastThermalAlert: Date?
    private var lastDiskAlert: Date?

    // Minimum interval between repeat alerts of the same type
    private let alertCooldown: TimeInterval = 300 // 5 minutes

    private var hasRequestedPermission = false

    init() {
        // Permission requested lazily on first alert to avoid crashes outside .app bundles
    }

    func check(
        cpuUsage: Double,
        memoryPressure: MemoryMonitor.PressureLevel,
        thermalState: ThermalMonitor.ThermalState,
        volumes: [StorageMonitor.VolumeInfo]
    ) {
        guard config.enabled else { return }

        checkCPU(cpuUsage)
        checkMemory(memoryPressure)
        checkThermal(thermalState)
        checkDiskSpace(volumes)
    }

    // MARK: - CPU

    private func checkCPU(_ usage: Double) {
        if usage >= config.cpuThreshold {
            if cpuHighStart == nil {
                cpuHighStart = Date()
            } else if let start = cpuHighStart,
                      Date().timeIntervalSince(start) >= Double(config.cpuSustainSeconds) {
                sendAlert(
                    title: "High CPU Usage",
                    body: "CPU has been above \(Int(config.cpuThreshold))% for \(config.cpuSustainSeconds) seconds. Currently at \(Formatters.formatPercentage(usage))."
                )
                cpuHighStart = Date() // Reset to avoid repeated rapid alerts
            }
        } else {
            cpuHighStart = nil
        }
    }

    // MARK: - Memory

    private func checkMemory(_ pressure: MemoryMonitor.PressureLevel) {
        guard config.memoryPressureAlert else { return }
        guard pressure == .warning || pressure == .critical else { return }
        guard shouldAlert(lastAlert: lastMemoryAlert) else { return }

        lastMemoryAlert = Date()
        sendAlert(
            title: "Memory Pressure \(pressure.rawValue)",
            body: pressure == .critical
                ? "System memory is critically low. Applications may become unresponsive."
                : "System memory is becoming constrained. Consider closing unused applications."
        )
    }

    // MARK: - Thermal

    private func checkThermal(_ state: ThermalMonitor.ThermalState) {
        guard config.thermalAlert else { return }
        guard state == .serious || state == .critical else { return }
        guard shouldAlert(lastAlert: lastThermalAlert) else { return }

        lastThermalAlert = Date()
        sendAlert(
            title: "Thermal Throttling: \(state.rawValue)",
            body: state == .critical
                ? "System is critically hot. Significant performance throttling is active."
                : "System is hot. Performance is being reduced to manage temperature."
        )
    }

    // MARK: - Disk Space

    private func checkDiskSpace(_ volumes: [StorageMonitor.VolumeInfo]) {
        for volume in volumes {
            let freePercent = 100 - volume.usedPercent
            if freePercent < config.diskSpaceThreshold {
                guard shouldAlert(lastAlert: lastDiskAlert) else { return }
                lastDiskAlert = Date()
                sendAlert(
                    title: "Low Disk Space: \(volume.name)",
                    body: "Only \(Formatters.formatBytes(volume.freeBytes)) free (\(Formatters.formatPercentage(freePercent, decimals: 1)) remaining) on \(volume.name)."
                )
                break // One alert per check cycle
            }
        }
    }

    // MARK: - Notifications

    private func ensurePermission() {
        guard !hasRequestedPermission else { return }
        hasRequestedPermission = true
        // Guard against running outside a proper .app bundle
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func sendAlert(title: String, body: String) {
        ensurePermission()
        guard Bundle.main.bundleIdentifier != nil else {
            // Running via swift run — just log to stdout
            print("[MacPerf Alert] \(title): \(body)")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func shouldAlert(lastAlert: Date?) -> Bool {
        guard let last = lastAlert else { return true }
        return Date().timeIntervalSince(last) >= alertCooldown
    }
}
