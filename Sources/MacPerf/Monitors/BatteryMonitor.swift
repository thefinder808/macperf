import Foundation
import IOKit

final class BatteryMonitor {
    struct Sample {
        let isPresent: Bool
        let currentPercent: Double       // 0-100
        let maxCapacity: Int             // mAh
        let designCapacity: Int          // mAh
        let cycleCount: Int
        let temperature: Double          // Celsius
        let isCharging: Bool
        let isPluggedIn: Bool
        let voltage: Double              // Volts
        let amperage: Double             // mA (negative = discharging)
        let timeRemaining: Int           // minutes
        let healthPercent: Double        // maxCapacity / designCapacity * 100
    }

    static func isBatteryPresent() -> Bool {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return false }
        IOObjectRelease(service)
        return true
    }

    func sample() -> Sample {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return emptySample() }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else {
            return emptySample()
        }

        // On modern macOS, CurrentCapacity/MaxCapacity are percentages (0-100).
        // AppleRawCurrentCapacity/AppleRawMaxCapacity have the actual mAh values.
        let rawMaxCapacity = intValue(dict, "AppleRawMaxCapacity") ?? intValue(dict, "MaxCapacity") ?? 0
        let rawCurrentCapacity = intValue(dict, "AppleRawCurrentCapacity") ?? intValue(dict, "CurrentCapacity") ?? 0
        let currentCapacity = intValue(dict, "CurrentCapacity") ?? 0
        let maxCapacity = rawMaxCapacity
        let designCapacity = intValue(dict, "DesignCapacity") ?? 1
        let cycleCount = intValue(dict, "CycleCount") ?? 0
        let rawTemp = intValue(dict, "Temperature") ?? 0
        let temperature = Double(rawTemp) / 100.0
        let isCharging = boolValue(dict, "IsCharging")
        let isPluggedIn = boolValue(dict, "ExternalConnected")
        let rawVoltage = intValue(dict, "Voltage") ?? 0
        let voltage = Double(rawVoltage) / 1000.0
        let amperage = Double(intValue(dict, "InstantAmperage") ?? 0)
        let timeRemaining = intValue(dict, "TimeRemaining") ?? 0

        // CurrentCapacity is 0-100 percentage on modern macOS
        let currentPercent: Double
        if currentCapacity <= 100 {
            currentPercent = Double(currentCapacity)
        } else {
            currentPercent = rawMaxCapacity > 0 ? Double(rawCurrentCapacity) / Double(rawMaxCapacity) * 100 : 0
        }

        let healthPercent = designCapacity > 0 ? Double(maxCapacity) / Double(designCapacity) * 100 : 0

        return Sample(
            isPresent: true,
            currentPercent: currentPercent,
            maxCapacity: maxCapacity,
            designCapacity: designCapacity,
            cycleCount: cycleCount,
            temperature: temperature,
            isCharging: isCharging,
            isPluggedIn: isPluggedIn,
            voltage: voltage,
            amperage: amperage,
            timeRemaining: timeRemaining,
            healthPercent: min(healthPercent, 100)
        )
    }

    private func intValue(_ dict: [String: Any], _ key: String) -> Int? {
        (dict[key] as? NSNumber)?.intValue
    }

    private func boolValue(_ dict: [String: Any], _ key: String) -> Bool {
        (dict[key] as? NSNumber)?.boolValue ?? false
    }

    private func emptySample() -> Sample {
        Sample(isPresent: false, currentPercent: 0, maxCapacity: 0, designCapacity: 0,
               cycleCount: 0, temperature: 0, isCharging: false, isPluggedIn: false,
               voltage: 0, amperage: 0, timeRemaining: 0, healthPercent: 0)
    }
}
