#if os(macOS)
import Foundation

enum BundledQwenASRServiceError: LocalizedError {
    case unsupportedURL(String)
    case missingBundleResource(String)
    case incompatibleExistingService(String)
    case launchFailed(String)
    case healthTimedOut(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedURL(let url):
            return "本地 Qwen3 服务地址不受支持：\(url)。closed alpha 只允许 http://127.0.0.1 或 localhost。"
        case .missingBundleResource(let path):
            return "closed alpha 包缺少本地 Qwen3 运行资源：\(path)。请重新安装完整 DMG。"
        case .incompatibleExistingService(let detail):
            return "127.0.0.1:18096 已有不兼容服务：\(detail)。请退出占用该端口的程序后重试。"
        case .launchFailed(let detail):
            return "无法启动内置 Qwen3 本地服务：\(detail)。"
        case .healthTimedOut(let logPath):
            return "内置 Qwen3 本地服务启动超时。日志：\(logPath)"
        }
    }
}

final class BundledQwenASRServiceManager: LocalASRServiceManaging {
    private static let expectedServiceName = "qwen3-mlx-segmented-cache-service"
    private static let expectedModelId = "qwen3-asr-0.6b-mlx-8bit"

    private let queue = DispatchQueue(label: "LocalVoiceInput.BundledQwenASRServiceManager")
    private let fileManager: FileManager
    private var managedProcess: Process?
    private var lastPrepareFailed = false

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func prepare(config: AppConfig) {
        guard shouldManage(config: config) else { return }
        queue.async { [weak self] in
            guard let self else { return }
            if case .failure = self.ensureReadyLocked(config: config, waitSeconds: 180) {
                self.lastPrepareFailed = true
            }
        }
    }

    func ensureReady(config: AppConfig) -> Result<Void, Error> {
        guard shouldManage(config: config) else { return .success(()) }
        return queue.sync {
            ensureReadyLocked(config: config, waitSeconds: lastPrepareFailed ? 180 : 60)
        }
    }

    func stopManagedService() {
        queue.sync {
            guard let process = managedProcess else { return }
            if process.isRunning {
                process.terminate()
                Thread.sleep(forTimeInterval: 0.2)
                if process.isRunning {
                    process.interrupt()
                }
            }
            managedProcess = nil
        }
    }

    private func shouldManage(config: AppConfig) -> Bool {
        !config.mockASR && config.asrBackend == .localHTTP
    }

    private func ensureReadyLocked(config: AppConfig, waitSeconds: Int) -> Result<Void, Error> {
        guard let serviceURL = URL(string: config.asrHTTPURL), LocalHTTPASRClient.isAllowedLoopbackURL(serviceURL) else {
            return .failure(BundledQwenASRServiceError.unsupportedURL(config.asrHTTPURL))
        }

        if let metadata = fetchMetadata(serviceURL: serviceURL) {
            if Self.metadataCompatibilityFailure(for: metadata) == nil {
                lastPrepareFailed = false
                return .success(())
            }
            return .failure(BundledQwenASRServiceError.incompatibleExistingService(describe(metadata: metadata)))
        }

        if let managedProcess, managedProcess.isRunning {
            return waitForHealthyService(serviceURL: serviceURL, waitSeconds: waitSeconds)
        }

        do {
            let resources = try resolveResources()
            try launchService(resources: resources, serviceURL: serviceURL)
            let result = waitForHealthyService(serviceURL: serviceURL, waitSeconds: waitSeconds)
            if case .success = result {
                lastPrepareFailed = false
            }
            return result
        } catch {
            return .failure(error)
        }
    }

    private func waitForHealthyService(serviceURL: URL, waitSeconds: Int) -> Result<Void, Error> {
        let logPath = logURL().path
        for _ in 0..<max(1, waitSeconds) {
            if isCompatibleServiceHealthy(serviceURL: serviceURL) {
                return .success(())
            }
            if let managedProcess, !managedProcess.isRunning {
                return .failure(BundledQwenASRServiceError.launchFailed("服务进程已退出；请查看日志：\(logPath)"))
            }
            Thread.sleep(forTimeInterval: 1.0)
        }
        return .failure(BundledQwenASRServiceError.healthTimedOut(logPath))
    }

    private func isCompatibleServiceHealthy(serviceURL: URL) -> Bool {
        guard let metadata = fetchMetadata(serviceURL: serviceURL) else { return false }
        return Self.metadataCompatibilityFailure(for: metadata) == nil
    }

    static func metadataCompatibilityFailure(for metadata: [String: Any]) -> String? {
        guard (metadata["ok"] as? Bool) == true else { return "ok=false" }
        guard (metadata["service"] as? String) == Self.expectedServiceName else {
            return "service=\(metadata["service"] ?? "missing")"
        }
        let modelInfo = metadata["model_info"] as? [String: Any]
        guard (modelInfo?["id"] as? String) == Self.expectedModelId else {
            return "model_id=\(modelInfo?["id"] ?? "missing")"
        }
        if (metadata["fake_backend"] as? Bool) == true {
            return "fake_backend=true"
        }
        return nil
    }

    private func describe(metadata: [String: Any]) -> String {
        Self.metadataCompatibilityFailure(for: metadata) ?? "compatible"
    }

    private func fetchMetadata(serviceURL: URL) -> [String: Any]? {
        let url = serviceURL.appendingPathComponent("metadata")
        var request = URLRequest(url: url, timeoutInterval: 2)
        request.httpMethod = "GET"
        let semaphore = DispatchSemaphore(value: 0)
        var result: [String: Any]?
        let task = URLSession.shared.dataTask(with: request) { data, response, _ in
            defer { semaphore.signal() }
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data else {
                return
            }
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
            result = object
        }
        task.resume()
        if semaphore.wait(timeout: .now() + 2.5) == .timedOut {
            task.cancel()
            return nil
        }
        return result
    }

    private struct Resources {
        let python: URL
        let serviceScript: URL
        let model: URL
        let mlxAudio: URL
        let registry: URL
        let spool: URL
    }

    private func resolveResources() throws -> Resources {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw BundledQwenASRServiceError.missingBundleResource("Bundle resources")
        }
        let root = resourceURL.appendingPathComponent("AlphaRuntime", isDirectory: true)
        let resources = Resources(
            python: root.appendingPathComponent("python/bin/python"),
            serviceScript: root.appendingPathComponent("services/asr_streaming/qwen3_mlx_segmented_cache_service.py"),
            model: root.appendingPathComponent("models/qwen3-asr-0.6b-mlx-8bit", isDirectory: true),
            mlxAudio: root.appendingPathComponent("repos/mlx-audio", isDirectory: true),
            registry: root.appendingPathComponent("services/asr_streaming/model_registry.json"),
            spool: ConfigPaths.cacheDirectory.appendingPathComponent("qwen3-service-spool", isDirectory: true)
        )

        for url in [resources.python, resources.serviceScript, resources.registry] where !fileManager.fileExists(atPath: url.path) {
            throw BundledQwenASRServiceError.missingBundleResource(url.path)
        }
        var isDirectory: ObjCBool = false
        for url in [resources.model, resources.mlxAudio] {
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                throw BundledQwenASRServiceError.missingBundleResource(url.path)
            }
        }
        try fileManager.createDirectory(at: resources.spool, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: ConfigPaths.logsDirectory, withIntermediateDirectories: true)
        return resources
    }

    private func launchService(resources: Resources, serviceURL: URL) throws {
        guard let host = serviceURL.host else {
            throw BundledQwenASRServiceError.unsupportedURL(serviceURL.absoluteString)
        }
        let port = serviceURL.port ?? 80
        let process = Process()
        process.executableURL = resources.python
        process.currentDirectoryURL = resources.serviceScript.deletingLastPathComponent()
        process.arguments = [
            "-u",
            resources.serviceScript.path,
            "serve",
            "--host", host,
            "--port", String(port),
            "--model-id", "qwen3-asr-0.6b-mlx-8bit",
            "--model", resources.model.path,
            "--mlx-audio-source", resources.mlxAudio.path,
            "--registry", resources.registry.path,
            "--spool-dir", resources.spool.path
        ]
        var environment = ProcessInfo.processInfo.environment
        environment["PYTHONUNBUFFERED"] = "1"
        environment["PYTHONNOUSERSITE"] = "1"
        environment["PATH"] = resources.python.deletingLastPathComponent().path + ":" + (environment["PATH"] ?? "/usr/bin:/bin")
        process.environment = environment

        let log = logURL()
        if !fileManager.fileExists(atPath: log.path) {
            fileManager.createFile(atPath: log.path, contents: nil)
        }
        if let handle = try? FileHandle(forWritingTo: log) {
            _ = try? handle.seekToEnd()
            process.standardOutput = handle
            process.standardError = handle
        }

        do {
            try process.run()
            managedProcess = process
        } catch {
            throw BundledQwenASRServiceError.launchFailed(error.localizedDescription)
        }
    }

    private func logURL() -> URL {
        ConfigPaths.logsDirectory.appendingPathComponent("qwen3-service.log")
    }
}
#endif
