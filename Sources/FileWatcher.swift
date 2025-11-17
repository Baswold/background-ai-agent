import Foundation
import CoreServices

class FileWatcher {
    private var streamRef: FSEventStreamRef?
    private var isRunning = false
    private var watchedPaths: [String] = []
    private var callback: ((String, FSEventStreamEventFlags) -> Void)?
    private let debounceQueue = DispatchQueue(label: "com.backgroundai.filewatcher.debounce")
    private var pendingFiles: Set<String> = []
    private var debounceTimer: Timer?

    func start(watchingPaths paths: [String], onChange: @escaping (String, FSEventStreamEventFlags) -> Void) {
        guard !isRunning else { return }

        watchedPaths = paths
        callback = onChange

        let pathsToWatch = paths as CFArray
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let streamCallback: FSEventStreamCallback = { (
            streamRef,
            clientCallBackInfo,
            numEvents,
            eventPaths,
            eventFlags,
            eventIds
        ) in
            guard let info = clientCallBackInfo else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()

            let paths = Unmanaged<CFArray>.fromOpaque(eventPaths).takeUnretainedValue() as! [String]

            for (index, path) in paths.enumerated() {
                let flags = eventFlags[index]
                watcher.handleFileEvent(path: path, flags: flags)
            }
        }

        streamRef = FSEventStreamCreate(
            nil,
            streamCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0, // Latency in seconds
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        )

        if let streamRef = streamRef {
            FSEventStreamScheduleWithRunLoop(streamRef, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
            FSEventStreamStart(streamRef)
            isRunning = true
            print("📁 File watcher started for paths: \(paths)")
        }
    }

    func stop() {
        guard isRunning, let streamRef = streamRef else { return }

        FSEventStreamStop(streamRef)
        FSEventStreamInvalidate(streamRef)
        FSEventStreamRelease(streamRef)

        self.streamRef = nil
        isRunning = false
        print("🛑 File watcher stopped")
    }

    private func handleFileEvent(path: String, flags: FSEventStreamEventFlags) {
        // Filter for code files only
        let codeExtensions = ["swift", "js", "ts", "tsx", "jsx", "py", "go", "rs", "java", "kt", "cpp", "c", "h", "hpp", "m", "mm", "rb", "php"]
        let pathExtension = (path as NSString).pathExtension.lowercased()

        guard codeExtensions.contains(pathExtension) else { return }

        // Check event type
        let isModified = (flags & UInt32(kFSEventStreamEventFlagItemModified)) != 0
        let isCreated = (flags & UInt32(kFSEventStreamEventFlagItemCreated)) != 0

        guard isModified || isCreated else { return }

        print("📝 File changed: \(path)")

        // Debounce - group rapid changes
        debounceQueue.async { [weak self] in
            self?.pendingFiles.insert(path)
            self?.scheduleDebounce()
        }
    }

    private func scheduleDebounce() {
        debounceTimer?.invalidate()

        debounceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            self?.processPendingFiles()
        }
    }

    private func processPendingFiles() {
        debounceQueue.sync {
            let files = Array(pendingFiles)
            pendingFiles.removeAll()

            DispatchQueue.main.async { [weak self] in
                for file in files {
                    self?.callback?(file, 0)
                }
            }
        }
    }

    func addPath(_ path: String) {
        guard !watchedPaths.contains(path) else { return }

        watchedPaths.append(path)

        if isRunning {
            stop()
            start(watchingPaths: watchedPaths, onChange: callback ?? { _, _ in })
        }
    }

    func removePath(_ path: String) {
        watchedPaths.removeAll { $0 == path }

        if isRunning {
            stop()
            start(watchingPaths: watchedPaths, onChange: callback ?? { _, _ in })
        }
    }
}

class CodeFileMonitor {
    private let fileWatcher = FileWatcher()
    private var analyzedFiles: [String: Date] = [:]
    private var activityCallback: ((Activity) -> Void)?
    private let analysisQueue = DispatchQueue(label: "com.backgroundai.analysis", qos: .utility)

    func start(onActivity: @escaping (Activity) -> Void) {
        activityCallback = onActivity

        // Watch common project directories
        var pathsToWatch = Settings.shared.watchedDirectories

        // Auto-detect common project locations
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let commonPaths = [
            homeDir.appendingPathComponent("Projects").path,
            homeDir.appendingPathComponent("Developer").path,
            homeDir.appendingPathComponent("Code").path,
            homeDir.appendingPathComponent("workspace").path,
            homeDir.appendingPathComponent("Documents/GitHub").path
        ]

        for path in commonPaths {
            if FileManager.default.fileExists(atPath: path) {
                pathsToWatch.append(path)
            }
        }

        // Remove duplicates
        pathsToWatch = Array(Set(pathsToWatch))

        guard !pathsToWatch.isEmpty else {
            print("⚠️ No directories to watch. Add them in settings.")
            return
        }

        fileWatcher.start(watchingPaths: pathsToWatch) { [weak self] filePath, _ in
            self?.analyzeFile(at: filePath)
        }

        print("👀 Code file monitor started, watching \(pathsToWatch.count) directories")
    }

    func stop() {
        fileWatcher.stop()
    }

    private func analyzeFile(at path: String) {
        // Rate limit - don't analyze same file within 30 seconds
        if let lastAnalyzed = analyzedFiles[path],
           Date().timeIntervalSince(lastAnalyzed) < 30 {
            return
        }

        analyzedFiles[path] = Date()

        analysisQueue.async { [weak self] in
            self?.performAnalysis(on: path)
        }
    }

    private func performAnalysis(on path: String) {
        guard let code = try? String(contentsOfFile: path, encoding: .utf8) else {
            return
        }

        let fileName = (path as NSString).lastPathComponent
        let language = detectLanguage(from: path)

        print("🔍 Analyzing: \(fileName)")

        // Use AI service for real analysis
        Task {
            do {
                let analysis = try await AIService.shared.analyzeCode(code, language: language)

                // Report issues found
                for issue in analysis.issues where issue.severity == "high" || issue.severity == "medium" {
                    let activity = Activity(
                        title: "Issue Found: \(fileName)",
                        description: "\(issue.type.capitalized): \(issue.description)",
                        type: .vsCodeFix
                    )

                    await MainActor.run {
                        self.activityCallback?(activity)
                    }

                    // Auto-fix if enabled
                    if Settings.shared.enableCodeAnalysis && AppConfig.enableCodeFixes {
                        await self.attemptAutoFix(file: path, issue: issue, code: code, language: language)
                    }
                }

                if !analysis.issues.isEmpty {
                    print("✅ Analysis complete: Found \(analysis.issues.count) issues in \(fileName)")
                }

            } catch {
                print("❌ Analysis error: \(error)")
            }
        }
    }

    private func attemptAutoFix(file: String, issue: CodeAnalysis.Issue, code: String, language: String) async {
        do {
            let fixedCode = try await AIService.shared.suggestCodeFix(
                issue: issue.description,
                code: code,
                language: language
            )

            // Save the fix to a backup location
            let fileName = (file as NSString).lastPathComponent
            let fixPath = AppConfig.codeFixesDir
                .appendingPathComponent("\(fileName).\(Date().timeIntervalSince1970).fix")

            try fixedCode.write(to: fixPath, atomically: true, encoding: .utf8)

            let activity = Activity(
                title: "Fix Ready: \(fileName)",
                description: "Auto-fix generated for \(issue.type). Check \(fixPath.lastPathComponent)",
                type: .vsCodeFix
            )

            await MainActor.run {
                self.activityCallback?(activity)
            }

            print("💾 Fix saved: \(fixPath.path)")

        } catch {
            print("❌ Auto-fix error: \(error)")
        }
    }

    private func detectLanguage(from path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        let languageMap: [String: String] = [
            "swift": "swift",
            "js": "javascript",
            "ts": "typescript",
            "tsx": "typescript",
            "jsx": "javascript",
            "py": "python",
            "go": "go",
            "rs": "rust",
            "java": "java",
            "kt": "kotlin",
            "cpp": "cpp",
            "c": "c",
            "rb": "ruby",
            "php": "php"
        ]
        return languageMap[ext] ?? ext
    }

    func addWatchPath(_ path: String) {
        fileWatcher.addPath(path)
        Settings.shared.watchedDirectories.append(path)
    }
}
