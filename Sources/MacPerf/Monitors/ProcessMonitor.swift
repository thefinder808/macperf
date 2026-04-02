import Foundation
import Darwin

final class ProcessMonitor {
    private var previousCPUTimes: [Int32: (user: UInt64, system: UInt64, timestamp: Date)] = [:]
    private var previousDiskIO: [Int32: (read: UInt64, written: UInt64, timestamp: Date)] = [:]

    func sample() -> [ProcessEntry] {
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

        // Clean up stale entries
        let activePids = Set(entries.map(\.pid))
        previousCPUTimes = previousCPUTimes.filter { activePids.contains($0.key) }
        previousDiskIO = previousDiskIO.filter { activePids.contains($0.key) }

        return entries
    }

    /// Read file descriptors for a specific process (on-demand, not in hot loop)
    func readFileDescriptors(pid: Int32) -> (openFiles: Int, connections: Int) {
        let bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, nil, 0)
        guard bufferSize > 0 else { return (0, 0) }

        let fdInfoSize = Int32(MemoryLayout<proc_fdinfo>.size)
        let count = bufferSize / fdInfoSize
        var fds = [proc_fdinfo](repeating: proc_fdinfo(), count: Int(count))
        let result = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, &fds, bufferSize)
        guard result > 0 else { return (0, 0) }

        let actualCount = Int(result / fdInfoSize)
        var openFiles = 0
        var connections = 0

        for i in 0..<actualCount {
            let fdtype = UInt32(fds[i].proc_fdtype)
            if fdtype == PROX_FDTYPE_VNODE { openFiles += 1 }
            else if fdtype == PROX_FDTYPE_SOCKET { connections += 1 }
        }

        return (openFiles, connections)
    }

    private func readProcess(pid: Int32, now: Date) -> ProcessEntry? {
        // Get basic task info (CPU time, memory, threads)
        var taskInfo = proc_taskinfo()
        let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.size)
        let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskInfoSize)
        guard taskResult == taskInfoSize else { return nil }

        // Get process name and path
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        proc_name(pid, &pathBuffer, UInt32(MAXPATHLEN))
        var name = String(cString: pathBuffer)

        // Get full path (also used for commandArgs)
        var fullPathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        proc_pidpath(pid, &fullPathBuffer, UInt32(MAXPATHLEN))
        let fullPath = String(cString: fullPathBuffer)

        if name.isEmpty {
            name = (fullPath as NSString).lastPathComponent
        }
        guard !name.isEmpty else { return nil }

        // Get parent PID and state
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
                let totalDelta = Double(userDelta + systemDelta) / 1_000_000_000
                cpuUsage = (totalDelta / elapsed) * 100
                cpuUsage = min(cpuUsage, Double(taskInfo.pti_threadnum) * 100)
            }
        }
        previousCPUTimes[pid] = (user: currentUserTime, system: currentSystemTime, timestamp: now)

        // Disk I/O via proc_pid_rusage
        var diskReadRate: Double = 0
        var diskWriteRate: Double = 0
        var rusage = rusage_info_v4()
        let rusageResult = withUnsafeMutablePointer(to: &rusage) { ptr in
            ptr.withMemoryRebound(to: Optional<rusage_info_t>.self, capacity: 1) { rebound in
                proc_pid_rusage(pid, RUSAGE_INFO_V4, rebound)
            }
        }
        if rusageResult == 0 {
            let currentRead = rusage.ri_diskio_bytesread
            let currentWritten = rusage.ri_diskio_byteswritten

            if let previous = previousDiskIO[pid] {
                let elapsed = now.timeIntervalSince(previous.timestamp)
                if elapsed > 0 {
                    diskReadRate = currentRead >= previous.read ? Double(currentRead - previous.read) / elapsed : 0
                    diskWriteRate = currentWritten >= previous.written ? Double(currentWritten - previous.written) / elapsed : 0
                }
            }
            previousDiskIO[pid] = (read: currentRead, written: currentWritten, timestamp: now)
        }

        // Memory
        let memoryBytes = UInt64(taskInfo.pti_resident_size)
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

        // Energy impact
        let energyScore = cpuUsage * 1.0 + Double(memoryBytes) / 1_073_741_824 * 2.0
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
            gpuUsage: 0,
            energyImpact: energy,
            diskReadBytesPerSec: diskReadRate,
            diskWriteBytesPerSec: diskWriteRate,
            threadCount: Int32(threadCount),
            state: state,
            connectionCount: 0,
            openFileCount: 0,
            commandArgs: fullPath
        )
    }
}
