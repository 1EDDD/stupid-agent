// The app is iOS-only; the guard lets `swift test` build the package on macOS for the core tests.
#if os(iOS)
import Darwin
import Foundation
import PiTools
import StupidAgentCore

/// Other apps' data containers and shared App Groups, reached through `SandboxBridge`.
///
/// Container directories are not listable from inside the sandbox, so discovery grants each root (which works for
/// App Groups on iOS 27) and, when that fails, brute-forces inodes with `fsgetpath` and reads the container
/// identifier xattr from every candidate. Discovery runs once per launch and the grants stay for the process.
final class SandboxContainers: AppContainerAccess, @unchecked Sendable {
    /// The App Group declared in App.entitlements and stupid-app.yml.
    static let groupIdentifier = SandboxBridge.groupIdentifier

    /// The directory each kind of container lives in.
    private static let appRoot = "/var/mobile/Containers/Data/Application"
    private static let groupRoot = "/var/mobile/Containers/Shared/AppGroup"

    /// A bound on the inode scan, in case a device's temporary directory has an implausibly high inode.
    private static let maximumInode: UInt64 = 50_000_000

    private let lock = NSLock()
    private var cached: [AppContainer]?
    private var discovery: Task<[AppContainer], Error>?

    var isAvailable: Bool {
        #if targetEnvironment(simulator)
        false
        #else
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 26 else { return false }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Self.groupIdentifier) != nil
        #endif
    }

    func containers() async throws -> [AppContainer] {
        let current = withLock { (cached, discovery) }
        if let cached = current.0 { return cached }
        if let discovery = current.1 { return try await discovery.value }
        let task = Task.detached(priority: .userInitiated) { try self.discover() }
        withLock { discovery = task }

        do {
            let containers = try await task.value
            withLock {
                cached = containers
                discovery = nil
            }
            return containers
        } catch {
            withLock { discovery = nil }
            throw error
        }
    }

    /// The cached containers and discovery task, under the lock.
    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    func root(for container: AppContainer) async throws -> URL {
        _ = try SandboxBridge.shared.grant(container.path)
        return URL(fileURLWithPath: container.path).resolvingSymlinksInPath()
    }

    private func discover() throws -> [AppContainer] {
        var containers: [AppContainer] = []
        containers += candidates(in: Self.appRoot).compactMap { try? container(kind: .app, path: $0) }
        containers += candidates(in: Self.groupRoot).compactMap { try? container(kind: .group, path: $0) }
        return containers.sorted { left, right in
            left.kind == right.kind
                ? left.identifier.localizedStandardCompare(right.identifier) == .orderedAscending
                : left.kind.rawValue < right.kind.rawValue
        }
    }

    /// The entries of a container root, by listing it when the grant allows that and by inode scan when it doesn't.
    private func candidates(in root: String) -> [String] {
        if let listed = try? listedChildren(of: root) { return listed }
        return (try? leakedChildren(of: root)) ?? []
    }

    private func listedChildren(of root: String) throws -> [String] {
        let grant = try SandboxBridge.shared.grant(root, checkTarget: false)
        defer { SandboxBridge.shared.release(grant) }
        return try FileManager.default.contentsOfDirectory(atPath: root).map { (root as NSString).appendingPathComponent($0) }
    }

    /// The container at a path, with its grant kept. Paths without an identifier, such as ordinary directories that
    /// the scan turned up, are not containers.
    private func container(kind: AppContainer.Kind, path: String) throws -> AppContainer? {
        let grant = try SandboxBridge.shared.grant(path)
        guard let identifier = Self.identifier(at: path) else {
            SandboxBridge.shared.release(grant)
            return nil
        }
        return AppContainer(kind: kind, identifier: identifier, path: path)
    }

    /// The container identifier containermanager stores on a container directory.
    private static func identifier(at path: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 512)
        let length = getxattr(path, "com.apple.containermanager.identifier", &buffer, 511, 0, 0)
        guard length > 0 else { return nil }
        return SandboxBridge.string(from: buffer, length: length)
    }

    // MARK: - Inode scan

    /// Every direct child of `root`, found by resolving inode numbers to paths.
    ///
    /// Parent directories can't be granted on iOS 26 and 27 (except App Groups on 27), so the container UUIDs are
    /// found by scanning the volume's inodes. A freshly created file gives a bound for the scan: inodes are
    /// allocated in increasing order on APFS, so nothing older is above it.
    private func leakedChildren(of root: String) throws -> [String] {
        var status = statfs()
        guard statfs(root, &status) == 0 else {
            throw WorkspaceError("Couldn't scan \(root) for containers.")
        }
        var fileSystem = status.f_fsid
        let limit = try Self.scanLimit()
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        var found: [String] = []

        for inode in 1 ... limit {
            if inode % 10_000 == 0, Task.isCancelled { break }
            let length = fsgetpath(&buffer, buffer.count, &fileSystem, inode)
            guard length > 0 else { continue }
            let path = String(decoding: buffer.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            // fsgetpath reports /private/var as often as /var.
            let candidates = [path, path.hasPrefix("/private") ? String(path.dropFirst("/private".count)) : path]
            if let match = candidates.first(where: { Self.isDirectChild($0, of: root) }), !found.contains(match) {
                found.append(match)
            }
        }
        return found
    }

    private static func isDirectChild(_ path: String, of root: String) -> Bool {
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard path.hasPrefix(prefix) else { return false }
        return !path.dropFirst(prefix.count).contains("/")
    }

    /// An inode above every existing one, from a file this app creates in its own temporary directory.
    private static func scanLimit() throws -> UInt64 {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(".inode-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data().write(to: url)
        var status = stat()
        guard lstat(url.path, &status) == 0 else {
            throw WorkspaceError("Couldn't create a file to bound the container scan.")
        }
        return min(status.st_ino &+ 65_536, maximumInode)
    }
}

#endif
