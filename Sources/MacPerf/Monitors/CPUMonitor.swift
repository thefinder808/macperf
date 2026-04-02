import Foundation
import Darwin

final class CPUMonitor {
    struct Sample {
        let overallUsage: Double
        let userUsage: Double
        let systemUsage: Double
        let idleUsage: Double
        let perCoreUsages: [Double]
    }

    private var previousTicks: [[UInt32]] = []

    func sample() -> Sample {
        let currentTicks = readPerCoreTicks()

        guard !previousTicks.isEmpty, currentTicks.count == previousTicks.count else {
            previousTicks = currentTicks
            return Sample(overallUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 100, perCoreUsages: Array(repeating: 0, count: currentTicks.count))
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0
        var perCore: [Double] = []

        for i in 0..<currentTicks.count {
            let cur = currentTicks[i]
            let prev = previousTicks[i]

            let userDelta = UInt64(cur[Int(CPU_STATE_USER)]) - UInt64(prev[Int(CPU_STATE_USER)])
            let systemDelta = UInt64(cur[Int(CPU_STATE_SYSTEM)]) - UInt64(prev[Int(CPU_STATE_SYSTEM)])
            let idleDelta = UInt64(cur[Int(CPU_STATE_IDLE)]) - UInt64(prev[Int(CPU_STATE_IDLE)])
            let niceDelta = UInt64(cur[Int(CPU_STATE_NICE)]) - UInt64(prev[Int(CPU_STATE_NICE)])

            let total = userDelta + systemDelta + idleDelta + niceDelta
            if total > 0 {
                let coreUsage = Double(userDelta + systemDelta + niceDelta) / Double(total) * 100
                perCore.append(coreUsage)
            } else {
                perCore.append(0)
            }

            totalUser += userDelta
            totalSystem += systemDelta
            totalIdle += idleDelta
            totalNice += niceDelta
        }

        previousTicks = currentTicks

        let grandTotal = totalUser + totalSystem + totalIdle + totalNice
        guard grandTotal > 0 else {
            return Sample(overallUsage: 0, userUsage: 0, systemUsage: 0, idleUsage: 100, perCoreUsages: perCore)
        }

        let overall = Double(totalUser + totalSystem + totalNice) / Double(grandTotal) * 100
        let user = Double(totalUser + totalNice) / Double(grandTotal) * 100
        let system = Double(totalSystem) / Double(grandTotal) * 100
        let idle = Double(totalIdle) / Double(grandTotal) * 100

        return Sample(
            overallUsage: overall,
            userUsage: user,
            systemUsage: system,
            idleUsage: idle,
            perCoreUsages: perCore
        )
    }

    /// Reads per-CPU tick counts via Mach host_processor_info
    private func readPerCoreTicks() -> [[UInt32]] {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUs,
            &cpuInfo,
            &numCPUInfo
        )

        guard result == KERN_SUCCESS, let info = cpuInfo else {
            return []
        }

        defer {
            // Must deallocate the Mach-allocated memory
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: info),
                vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.size)
            )
        }

        var ticks: [[UInt32]] = []
        let cpuLoadInfoCount = Int(CPU_STATE_MAX)

        for i in 0..<Int(numCPUs) {
            let base = i * cpuLoadInfoCount
            var coreTicks: [UInt32] = []
            for j in 0..<cpuLoadInfoCount {
                coreTicks.append(UInt32(bitPattern: info[base + j]))
            }
            ticks.append(coreTicks)
        }

        return ticks
    }
}
