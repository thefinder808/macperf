import Foundation
import Darwin

final class ProcessMonitor {
    private var previousCPUTimes: [Int32: (user: UInt64, system: UInt64, timestamp: Date)] = [:]

    func sample() -> [ProcessEntry] {
        // Get all PIDs
        let bufferSize = proc_listallpids(nil, 0)
        guard bufferSize > 0 else { return [] }

        var pids = [Int32](repeating: 0, count: Int(bufferSize))
        let actualSize = proc_listallpids(&pids, Int32(MemoryLayout<Int32>.size * pids.count))
        guard actualSize > 0 else { return [] }

        let pidCount = Int(actualSize)
        let now = Date()
        var entries: [ProcessEntry] = []
        entries.reserveCapacity(pidCount)

        for i in 0..<pidCount {
            let pid = pids[i]
            guard pid > 0 else { continue }

            guard let entry = readProcess(pid: pid, now: now) else { continue }
            entries.append(entry)
        }

        // Clean up stale entries from previousCPUTimes
        let activePids = Set(entries.map(\.pid))
        previousCPUTimes = previousCPUTimes.filter { activePids.contains($0.key) }

        return entries
    }

    private func readProcess(pid: Int32, now: Date) -> ProcessEntry? {
        // Get basic task info (CPU time, memory, threads, state)
        var taskInfo = proc_taskinfo()
        let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.size)
        let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskInfoSize)
        guard taskResult == taskInfoSize else { return nil }

        // Get process name
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        proc_name(pid, &pathBuffer, UInt32(MAXPATHLEN))
        var name = String(cString: pathBuffer)
        if name.isEmpty {
            // Try to get from path
            proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
            let path = String(cString: pathBuffer)
            name = (path as NSString).lastPathComponent
        }
        guard !name.isEmpty else { return nil }

        // Get parent PID
        var bsdInfo = proc_bsdinfo()
        let bsdInfoSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        let bsdResult = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsdInfo, bsdInfoSize)
        let parentPid: Int32 = bsdResult == bsdInfoSize ? Int32(bsdInfo.pbi_ppid) : 0

        // CPU usage via delta of user+system time
        let currentUserTime = taskInfo.pti_total_user
        let currentSystemTime = taskInfo.pti_total_system
        var cpuUsage: Double = 0

        if let previous = previousCPUTimes[pid] {
            let elapsed = now.timeIntervalSince(previous.timestamp)
            if elapsed > 0 {
                let userDelta = currentUserTime >= previous.user ? currentUserTime - previous.user : 0
                let systemDelta = currentSystemTime >= previous.system ? currentSystemTime - previous.system : 0
                // Convert from Mach absolute time (nanoseconds) to seconds
                let totalDelta = Double(userDelta + systemDelta) / 1_000_000_000
                cpuUsage = (totalDelta / elapsed) * 100
                cpuUsage = min(cpuUsage, Double(taskInfo.pti_threadnum) * 100) // Cap at threads * 100
            }
        }

        previousCPUTimes[pid] = (user: currentUserTime, system: currentSystemTime, timestamp: now)

        // Memory: resident size
        let memoryBytes = UInt64(taskInfo.pti_resident_size)

        // Thread count
        let threadCount = taskInfo.pti_threadnum

        // Process state
        let state: ProcessEntry.ProcessState
        switch bsdInfo.pbi_status {
        case 1: state = .idle
        case 2: state = .running
        case 3: state = .sleeping
        case 4: state = .stopped
        case 5: state = .zombie
        default: state = .unknown
        }

        // Energy impact: weighted combination of CPU + memory pressure
        let energyScore = cpuUsage * 1.0 + Double(memoryBytes) / 1_073_741_824 * 2.0 // GB factor
        let energy: ProcessEntry.EnergyLevel
        if energyScore > 15 { energy = .high }
        else if energyScore > 3 { energy = .medium }
        else { energy = .low }

        return ProcessEntry(
            id: pid,
            pid: pid,
            parentPid: parentPid,
            name: name,
            cpuUsage: cpuUsage,
            memoryBytes: memoryBytes,
            gpuUsage: 0,    // Will be populated in chunk 7 with IOAccelerator per-client
            energyImpact: energy,
            diskReadBytesPerSec: 0, // Per-process I/O requires PROC_PIDIO (future enhancement)
            diskWriteBytesPerSec: 0,
            threadCount: Int32(threadCount),
            state: state
        )
    }
}
