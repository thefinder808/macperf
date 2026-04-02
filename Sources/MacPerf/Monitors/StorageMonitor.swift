import Foundation

final class StorageMonitor {
    struct Sample {
        let volumes: [VolumeInfo]
    }

    struct VolumeInfo: Identifiable {
        let id: String           // mount point
        let name: String
        let mountPoint: String
        let totalBytes: UInt64
        let freeBytes: UInt64
        let usedBytes: UInt64
        let usedPercent: Double
        let fileSystem: String
        let isRemovable: Bool
    }

    func sample() -> Sample {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeLocalizedFormatDescriptionKey,
            .volumeIsRemovableKey,
        ]

        guard let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) else {
            return Sample(volumes: [])
        }

        var volumes: [VolumeInfo] = []

        for url in mountedVolumes {
            guard let resources = try? url.resourceValues(forKeys: keys) else { continue }

            let name = resources.volumeName ?? url.lastPathComponent
            let total = UInt64(resources.volumeTotalCapacity ?? 0)
            let free = UInt64(resources.volumeAvailableCapacity ?? 0)

            // Skip tiny volumes (system snapshots, etc.)
            guard total > 100_000_000 else { continue }

            let used = total > free ? total - free : 0
            let usedPct = total > 0 ? Double(used) / Double(total) * 100 : 0

            volumes.append(VolumeInfo(
                id: url.path,
                name: name,
                mountPoint: url.path,
                totalBytes: total,
                freeBytes: free,
                usedBytes: used,
                usedPercent: usedPct,
                fileSystem: resources.volumeLocalizedFormatDescription ?? "Unknown",
                isRemovable: resources.volumeIsRemovable ?? false
            ))
        }

        // Sort: root volume first, then by name
        volumes.sort { a, b in
            if a.mountPoint == "/" { return true }
            if b.mountPoint == "/" { return false }
            return a.name < b.name
        }

        return Sample(volumes: volumes)
    }
}
