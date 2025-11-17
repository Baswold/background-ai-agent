import Foundation
import CryptoKit

// MARK: - Comprehensive Caching System

/// Multi-tier caching system with memory and disk storage
class CacheManager {
    static let shared = CacheManager()

    private let memoryCache = NSCache<NSString, CacheEntry>()
    private let diskCacheDirectory: URL
    private let queue = DispatchQueue(label: "com.backgroundai.cache", qos: .utility)

    // Configuration
    private let maxMemoryCacheSizeMB = 50
    private let maxDiskCacheSizeMB = 200
    private let defaultTTL: TimeInterval = 3600 // 1 hour

    private init() {
        diskCacheDirectory = AppConfig.baseDirectory
            .appendingPathComponent("cache")

        // Configure memory cache
        memoryCache.totalCostLimit = maxMemoryCacheSizeMB * 1024 * 1024
        memoryCache.countLimit = 1000

        // Create disk cache directory
        try? FileManager.default.createDirectory(
            at: diskCacheDirectory,
            withIntermediateDirectories: true
        )

        // Clean up expired entries on init
        Task {
            await cleanupExpiredEntries()
        }

        Logger.shared.info("Cache manager initialized", category: .system)
    }

    // MARK: - Generic Caching

    func get<T: Codable>(_ key: String, type: T.Type) async -> T? {
        let cacheKey = generateCacheKey(key)

        // Try memory cache first
        if let entry = getFromMemoryCache(cacheKey), !entry.isExpired {
            Logger.shared.verbose("Cache hit (memory): \(key)", category: .performance)
            return entry.decode(type: T.self)
        }

        // Try disk cache
        if let entry = await getFromDiskCache(cacheKey), !entry.isExpired {
            Logger.shared.verbose("Cache hit (disk): \(key)", category: .performance)

            // Promote to memory cache
            saveToMemoryCache(cacheKey, entry: entry)

            return entry.decode(type: T.self)
        }

        Logger.shared.verbose("Cache miss: \(key)", category: .performance)
        return nil
    }

    func set<T: Codable>(_ key: String, value: T, ttl: TimeInterval? = nil) async {
        let cacheKey = generateCacheKey(key)
        let expiresAt = Date().addingTimeInterval(ttl ?? defaultTTL)

        guard let entry = CacheEntry(value: value, expiresAt: expiresAt) else {
            Logger.shared.error("Failed to create cache entry for: \(key)", category: .errorHandling)
            return
        }

        // Save to memory cache
        saveToMemoryCache(cacheKey, entry: entry)

        // Save to disk cache asynchronously
        await saveToDiskCache(cacheKey, entry: entry)

        Logger.shared.verbose("Cached: \(key) (TTL: \(ttl ?? defaultTTL)s)", category: .performance)
    }

    func remove(_ key: String) async {
        let cacheKey = generateCacheKey(key)

        // Remove from memory
        memoryCache.removeObject(forKey: cacheKey as NSString)

        // Remove from disk
        await removeFromDiskCache(cacheKey)

        Logger.shared.verbose("Removed from cache: \(key)", category: .performance)
    }

    func clear() async {
        // Clear memory cache
        memoryCache.removeAllObjects()

        // Clear disk cache
        await clearDiskCache()

        Logger.shared.info("Cache cleared", category: .system)
    }

    // MARK: - Specialized AI Response Caching

    func getCachedAIResponse(prompt: String, model: String) async -> String? {
        let key = "ai:\(model):\(prompt)"
        return await get(key, type: String.self)
    }

    func cacheAIResponse(prompt: String, model: String, response: String, ttl: TimeInterval = 7200) async {
        let key = "ai:\(model):\(prompt)"
        await set(key, value: response, ttl: ttl)
    }

    // MARK: - Code Analysis Caching

    func getCachedCodeAnalysis(code: String, language: String) async -> CodeAnalysis? {
        let key = "code:\(language):\(hashContent(code))"
        return await get(key, type: CodeAnalysis.self)
    }

    func cacheCodeAnalysis(code: String, language: String, analysis: CodeAnalysis) async {
        let key = "code:\(language):\(hashContent(code))"
        await set(key, value: analysis, ttl: 3600) // 1 hour
    }

    // MARK: - Screenshot Analysis Caching

    func getCachedScreenshotAnalysis(imageHash: String) async -> ScreenshotAnalysis? {
        let key = "screenshot:\(imageHash)"
        return await get(key, type: ScreenshotAnalysis.self)
    }

    func cacheScreenshotAnalysis(imageHash: String, analysis: ScreenshotAnalysis) async {
        let key = "screenshot:\(imageHash)"
        await set(key, value: analysis, ttl: 1800) // 30 minutes
    }

    // MARK: - Memory Cache Operations

    private func getFromMemoryCache(_ key: String) -> CacheEntry? {
        return memoryCache.object(forKey: key as NSString)
    }

    private func saveToMemoryCache(_ key: String, entry: CacheEntry) {
        let cost = entry.estimatedSize
        memoryCache.setObject(entry, forKey: key as NSString, cost: cost)
    }

    // MARK: - Disk Cache Operations

    private func getFromDiskCache(_ key: String) async -> CacheEntry? {
        let fileURL = diskCacheFileURL(for: key)

        return await withCheckedContinuation { continuation in
            queue.async {
                guard let data = try? Data(contentsOf: fileURL),
                      let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: entry)
            }
        }
    }

    private func saveToDiskCache(_ key: String, entry: CacheEntry) async {
        let fileURL = diskCacheFileURL(for: key)

        await withCheckedContinuation { continuation in
            queue.async {
                guard let data = try? JSONEncoder().encode(entry) else {
                    continuation.resume()
                    return
                }

                try? data.write(to: fileURL, options: .atomic)
                continuation.resume()
            }
        }
    }

    private func removeFromDiskCache(_ key: String) async {
        let fileURL = diskCacheFileURL(for: key)

        await withCheckedContinuation { continuation in
            queue.async {
                try? FileManager.default.removeItem(at: fileURL)
                continuation.resume()
            }
        }
    }

    private func clearDiskCache() async {
        await withCheckedContinuation { continuation in
            queue.async {
                try? FileManager.default.removeItem(at: self.diskCacheDirectory)
                try? FileManager.default.createDirectory(
                    at: self.diskCacheDirectory,
                    withIntermediateDirectories: true
                )
                continuation.resume()
            }
        }
    }

    // MARK: - Cleanup

    private func cleanupExpiredEntries() async {
        Logger.shared.info("Cleaning up expired cache entries...", category: .system)

        await withCheckedContinuation { continuation in
            queue.async {
                guard let files = try? FileManager.default.contentsOfDirectory(
                    at: self.diskCacheDirectory,
                    includingPropertiesForKeys: [.contentModificationDateKey]
                ) else {
                    continuation.resume()
                    return
                }

                var removedCount = 0

                for fileURL in files {
                    guard let data = try? Data(contentsOf: fileURL),
                          let entry = try? JSONDecoder().decode(CacheEntry.self, from: data) else {
                        continue
                    }

                    if entry.isExpired {
                        try? FileManager.default.removeItem(at: fileURL)
                        removedCount += 1
                    }
                }

                if removedCount > 0 {
                    Logger.shared.info("Removed \(removedCount) expired cache entries", category: .system)
                }

                continuation.resume()
            }
        }

        // Enforce disk cache size limit
        await enforceDiskCacheSizeLimit()
    }

    private func enforceDiskCacheSizeLimit() async {
        let maxBytes = maxDiskCacheSizeMB * 1024 * 1024

        await withCheckedContinuation { continuation in
            queue.async {
                guard let files = try? FileManager.default.contentsOfDirectory(
                    at: self.diskCacheDirectory,
                    includingPropertiesForKeys: [.fileSizeKey, .contentAccessDateKey]
                ) else {
                    continuation.resume()
                    return
                }

                // Calculate total size
                var totalSize = 0
                var fileInfos: [(url: URL, size: Int, accessDate: Date)] = []

                for fileURL in files {
                    guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                          let size = attributes[.size] as? Int,
                          let accessDate = attributes[.modificationDate] as? Date else {
                        continue
                    }

                    totalSize += size
                    fileInfos.append((fileURL, size, accessDate))
                }

                // If over limit, remove oldest files
                if totalSize > maxBytes {
                    // Sort by access date (oldest first)
                    fileInfos.sort { $0.accessDate < $1.accessDate }

                    var sizeToRemove = totalSize - maxBytes
                    var removedCount = 0

                    for info in fileInfos {
                        guard sizeToRemove > 0 else { break }

                        try? FileManager.default.removeItem(at: info.url)
                        sizeToRemove -= info.size
                        removedCount += 1
                    }

                    Logger.shared.info("Disk cache size limit enforced. Removed \(removedCount) files", category: .system)
                }

                continuation.resume()
            }
        }
    }

    // MARK: - Statistics

    func getCacheStatistics() async -> CacheStatistics {
        let diskSize = await getDiskCacheSize()
        let diskFileCount = await getDiskCacheFileCount()

        return CacheStatistics(
            memoryCacheCount: memoryCache.totalCostLimit,
            diskCacheSize: diskSize,
            diskCacheFileCount: diskFileCount,
            maxMemorySizeMB: maxMemoryCacheSizeMB,
            maxDiskSizeMB: maxDiskCacheSizeMB
        )
    }

    private func getDiskCacheSize() async -> UInt64 {
        return await withCheckedContinuation { continuation in
            queue.async {
                guard let files = try? FileManager.default.contentsOfDirectory(
                    at: self.diskCacheDirectory,
                    includingPropertiesForKeys: [.fileSizeKey]
                ) else {
                    continuation.resume(returning: 0)
                    return
                }

                var totalSize: UInt64 = 0
                for fileURL in files {
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                       let size = attributes[.size] as? UInt64 {
                        totalSize += size
                    }
                }

                continuation.resume(returning: totalSize)
            }
        }
    }

    private func getDiskCacheFileCount() async -> Int {
        return await withCheckedContinuation { continuation in
            queue.async {
                let count = (try? FileManager.default.contentsOfDirectory(
                    at: self.diskCacheDirectory,
                    includingPropertiesForKeys: nil
                ).count) ?? 0

                continuation.resume(returning: count)
            }
        }
    }

    // MARK: - Utilities

    private func generateCacheKey(_ key: String) -> String {
        return key.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? key
    }

    private func diskCacheFileURL(for key: String) -> URL {
        return diskCacheDirectory.appendingPathComponent(key)
    }

    private func hashContent(_ content: String) -> String {
        let data = Data(content.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Cache Entry

private class CacheEntry: NSObject, Codable {
    let data: Data
    let expiresAt: Date
    let createdAt: Date

    var isExpired: Bool {
        return Date() > expiresAt
    }

    var estimatedSize: Int {
        return data.count
    }

    init?<T: Codable>(value: T, expiresAt: Date) {
        guard let encoded = try? JSONEncoder().encode(value) else {
            return nil
        }

        self.data = encoded
        self.expiresAt = expiresAt
        self.createdAt = Date()
    }

    func decode<T: Codable>(type: T.Type) -> T? {
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let memoryCacheCount: Int
    let diskCacheSize: UInt64
    let diskCacheFileCount: Int
    let maxMemorySizeMB: Int
    let maxDiskSizeMB: Int

    var diskCacheSizeMB: Double {
        return Double(diskCacheSize) / 1024 / 1024
    }

    func formatted() -> String {
        """
        Cache Statistics:
        Memory: \(memoryCacheCount) entries (max: \(maxMemorySizeMB) MB)
        Disk: \(diskCacheFileCount) files (\(String(format: "%.2f", diskCacheSizeMB)) MB / \(maxDiskSizeMB) MB)
        """
    }
}
