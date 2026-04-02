import Foundation
import IOKit

// MARK: - Private IOKit HID API for temperature sensors (Apple Silicon)

@_silgen_name("IOHIDEventSystemClientCreate")
private func _HIDCreateClient(_ allocator: CFAllocator!) -> Unmanaged<AnyObject>?

@_silgen_name("IOHIDEventSystemClientSetMatching")
private func _HIDSetClientMatching(_ client: AnyObject, _ matching: CFDictionary)

@_silgen_name("IOHIDEventSystemClientCopyServices")
private func _HIDCopyServices(_ client: AnyObject) -> Unmanaged<NSArray>?

@_silgen_name("IOHIDServiceClientCopyProperty")
private func _HIDCopyProperty(_ service: AnyObject, _ key: CFString) -> Unmanaged<AnyObject>?

@_silgen_name("IOHIDServiceClientCopyEvent")
private func _HIDCopyEvent(_ service: AnyObject, _ type: UInt32, _ matching: Int32, _ options: UInt32) -> Unmanaged<AnyObject>?

@_silgen_name("IOHIDEventGetFloatValue")
private func _HIDGetFloatValue(_ event: AnyObject, _ field: Int32) -> Double

private let kHIDTemperatureEvent: UInt32 = 15
private let kHIDTemperatureField = Int32(15 << 16)

final class ThermalMonitor {
    struct Sample {
        let cpuTemperature: Double       // Celsius
        let gpuTemperature: Double       // Celsius
        let thermalState: ThermalState
        let fanSpeeds: [FanReading]
    }

    struct FanReading {
        let name: String
        let currentRPM: Double
        let minRPM: Double
        let maxRPM: Double
    }

    enum ThermalState: String {
        case nominal = "Nominal"
        case fair = "Fair"
        case serious = "Serious"
        case critical = "Critical"
    }

    private var smcConnection: io_connect_t = 0
    private var smcAvailable = false
    private var hidAvailable = false

    init() {
        openSMC()
        hidAvailable = checkHIDAccess()
    }

    deinit {
        if smcAvailable {
            IOServiceClose(smcConnection)
        }
    }

    func sample() -> Sample {
        // Try HID sensors first (Apple Silicon), then SMC (Intel), then estimate
        let hidTemps = hidAvailable ? readHIDTemperatures() : (cpu: nil as Double?, gpu: nil as Double?)

        let cpuTemp = hidTemps.cpu
                   ?? readSMCTemperature(key: "Tp09")  // CPU efficiency core 1 (Apple Silicon)
                   ?? readSMCTemperature(key: "Tp01")  // CPU performance core 1 (Apple Silicon)
                   ?? readSMCTemperature(key: "TC0P")  // CPU proximity (Intel)
                   ?? readSMCTemperature(key: "TC0p")  // lowercase variant
                   ?? readSMCTemperature(key: "Tc0a")  // CPU die variant
                   ?? readSMCTemperature(key: "TC0D")  // CPU die (Intel)
                   ?? readSMCTemperature(key: "TC0E")  // CPU die (Intel alternate)
                   ?? estimateCPUTemp()

        let gpuTemp = hidTemps.gpu
                   ?? readSMCTemperature(key: "Tg05")  // GPU (Apple Silicon)
                   ?? readSMCTemperature(key: "TG0P")  // GPU proximity (Intel)
                   ?? readSMCTemperature(key: "Tg0a")  // GPU die variant
                   ?? cpuTemp * 0.9                      // Rough estimate from CPU

        let fans = readFanSpeeds()

        let state: ThermalState
        let piState = ProcessInfo.processInfo.thermalState
        switch piState {
        case .nominal: state = .nominal
        case .fair: state = .fair
        case .serious: state = .serious
        case .critical: state = .critical
        @unknown default: state = .nominal
        }

        return Sample(
            cpuTemperature: cpuTemp,
            gpuTemperature: gpuTemp,
            thermalState: state,
            fanSpeeds: fans
        )
    }

    // MARK: - SMC Access

    // SMC key structure for reading values
    private struct SMCKeyData {
        struct Version {
            var major: UInt8 = 0
            var minor: UInt8 = 0
            var build: UInt8 = 0
            var reserved: UInt8 = 0
            var release: UInt16 = 0
        }
        struct PLimitData {
            var version: UInt16 = 0
            var length: UInt16 = 0
            var cpuPLimit: UInt32 = 0
            var gpuPLimit: UInt32 = 0
            var memPLimit: UInt32 = 0
        }
        struct KeyInfo {
            var dataSize: UInt32 = 0
            var dataType: UInt32 = 0
            var dataAttributes: UInt8 = 0
        }

        var key: UInt32 = 0
        var vers = Version()
        var pLimitData = PLimitData()
        var keyInfo = KeyInfo()
        var result: UInt8 = 0
        var status: UInt8 = 0
        var data8: UInt8 = 0
        var data32: UInt32 = 0
        var bytes: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                     UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                     UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                     UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8) =
            (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    }

    private func openSMC() {
        let matching = IOServiceMatching("AppleSMC")
        var service: io_service_t = 0
        service = IOServiceGetMatchingService(kIOMainPortDefault, matching)
        guard service != 0 else { return }
        defer { IOObjectRelease(service) }

        let result = IOServiceOpen(service, mach_task_self_, 0, &smcConnection)
        smcAvailable = (result == KERN_SUCCESS)
    }

    private func fourCharCode(_ str: String) -> UInt32 {
        var result: UInt32 = 0
        for char in str.utf8.prefix(4) {
            result = (result << 8) | UInt32(char)
        }
        return result
    }

    private func readSMCTemperature(key: String) -> Double? {
        guard smcAvailable else { return nil }

        // Step 1: Get key info (data size and type)
        var inputStruct = SMCKeyData()
        var outputStruct = SMCKeyData()

        inputStruct.key = fourCharCode(key)
        inputStruct.data8 = 9 // kSMCGetKeyInfo

        let inputSize = MemoryLayout<SMCKeyData>.size
        var outputSize = MemoryLayout<SMCKeyData>.size

        var result = IOConnectCallStructMethod(
            smcConnection,
            2, // kSMCHandleYPCEvent
            &inputStruct,
            inputSize,
            &outputStruct,
            &outputSize
        )

        guard result == KERN_SUCCESS else { return nil }

        // Step 2: Read the key value using the retrieved key info
        let keyInfo = outputStruct.keyInfo
        inputStruct.keyInfo = keyInfo
        inputStruct.data8 = 5 // kSMCReadKey
        outputStruct = SMCKeyData()

        result = IOConnectCallStructMethod(
            smcConnection,
            2, // kSMCHandleYPCEvent
            &inputStruct,
            inputSize,
            &outputStruct,
            &outputSize
        )

        guard result == KERN_SUCCESS else { return nil }

        // Decode based on data type
        let dataType = keyInfo.dataType
        let sp78 = fourCharCode("sp78") // signed 7.8 fixed-point
        let flt = fourCharCode("flt ")  // 32-bit float

        let temp: Double
        if dataType == sp78 {
            // sp78: signed 8.8 fixed-point (common for temperature keys)
            let raw = (Int16(outputStruct.bytes.0) << 8) | Int16(outputStruct.bytes.1)
            temp = Double(raw) / 256.0
        } else if dataType == flt {
            // flt: IEEE 754 float
            let raw = UInt32(outputStruct.bytes.0) << 24
                    | UInt32(outputStruct.bytes.1) << 16
                    | UInt32(outputStruct.bytes.2) << 8
                    | UInt32(outputStruct.bytes.3)
            temp = Double(Float(bitPattern: raw))
        } else {
            // Fallback: try unsigned 8.8 fixed-point
            let intPart = Double(outputStruct.bytes.0)
            let fracPart = Double(outputStruct.bytes.1) / 256.0
            temp = intPart + fracPart
        }

        // Sanity check — temperatures should be in reasonable range
        guard temp > 0 && temp < 130 else { return nil }
        return temp
    }

    private func readFanSpeeds() -> [FanReading] {
        // On Apple Silicon Macs, most models don't have user-accessible fan data
        // Return empty — will be populated if SMC fan keys are found
        return []
    }

    // MARK: - HID Temperature Sensors (Apple Silicon)

    private func checkHIDAccess() -> Bool {
        guard let clientRef = _HIDCreateClient(kCFAllocatorDefault) else { return false }
        let client = clientRef.takeRetainedValue()
        let matching: NSDictionary = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 0x0005]
        _HIDSetClientMatching(client, matching as CFDictionary)
        guard let servicesRef = _HIDCopyServices(client) else { return false }
        let services = servicesRef.takeRetainedValue()
        return services.count > 0
    }

    private func readHIDTemperatures() -> (cpu: Double?, gpu: Double?) {
        guard let clientRef = _HIDCreateClient(kCFAllocatorDefault) else { return (nil, nil) }
        let client = clientRef.takeRetainedValue()

        let matching: NSDictionary = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 0x0005]
        _HIDSetClientMatching(client, matching as CFDictionary)

        guard let servicesRef = _HIDCopyServices(client) else { return (nil, nil) }
        let services = servicesRef.takeRetainedValue()

        var cpuTemps: [Double] = []
        var gpuTemps: [Double] = []

        for i in 0..<services.count {
            let service = services[i] as AnyObject
            let name = _HIDCopyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String ?? ""

            guard let eventRef = _HIDCopyEvent(service, kHIDTemperatureEvent, 0, 0) else { continue }
            let event = eventRef.takeRetainedValue()

            let temp = _HIDGetFloatValue(event, kHIDTemperatureField)
            guard temp > 0 && temp < 130 else { continue }

            let lower = name.lowercased()
            if lower.contains("gpu") {
                gpuTemps.append(temp)
            } else if lower.contains("cpu") || lower.contains("soc") || lower.contains("die") {
                cpuTemps.append(temp)
            }
        }

        let cpuAvg = cpuTemps.isEmpty ? nil : cpuTemps.reduce(0, +) / Double(cpuTemps.count)
        let gpuAvg = gpuTemps.isEmpty ? nil : gpuTemps.reduce(0, +) / Double(gpuTemps.count)
        return (cpuAvg, gpuAvg)
    }

    /// Fallback temperature estimation from thermal state
    private func estimateCPUTemp() -> Double {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: return 45
        case .fair: return 65
        case .serious: return 85
        case .critical: return 100
        @unknown default: return 50
        }
    }
}
