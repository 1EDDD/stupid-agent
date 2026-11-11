import Foundation

struct DependencyNode: Decodable {
    let identity: String
    let path: String
    let dependencies: [DependencyNode]
}

struct PackageDump: Decodable {
    struct Product: Decodable {
        let name: String
        let targets: [String]
        let type: ProductType
    }
    enum ProductType: Decodable {
        case library([String])
        case executable
        case other
        private enum CodingKeys: String, CodingKey { case library, executable }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            if let libraries = try c.decodeIfPresent([String].self, forKey: .library) {
                self = .library(libraries)
            } else if c.contains(.executable) {
                self = .executable
            } else {
                self = .other
            }
        }
    }
    struct Target: Decodable {
        let name: String
        let moduleType: String
        let path: String?
        let sources: [String]?
        let productDependencies: [String]?
        let targetDependencies: [String]?
        let resources: [Resource]?
    }
    struct Resource: Decodable { let path: String }
    struct Platform: Decodable { let name: String; let version: String }
    struct Dependency: Decodable { let identity: String }
    let name: String
    let dependencies: [Dependency]?
    let products: [Product]?
    let targets: [Target]?
    let platforms: [Platform]?
}

private func jsonData(_ text: String) -> Data {
    guard let brace = text.firstIndex(of: "{") else { return Data(text.utf8) }
    return Data(text[brace...].utf8)
}

private func run(_ arguments: [String]) throws -> (Int32, String, String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = arguments
    let out = Pipe()
    let err = Pipe()
    process.standardOutput = out
    process.standardError = err
    try process.run()
    let stdout = out.fileHandleForReading.readDataToEndOfFile()
    let stderr = err.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return (
        process.terminationStatus,
        String(decoding: stdout, as: UTF8.self),
        String(decoding: stderr, as: UTF8.self)
    )
}

let swiftExecutable = CommandLine.arguments.dropFirst().first ?? "swift"
let decoder = JSONDecoder()
decoder.keyDecodingStrategy = .convertFromSnakeCase
let graphResult = try run([swiftExecutable, "package", "show-dependencies", "--format", "json"])
guard graphResult.0 == 0 else {
    fputs("show-dependencies failed:\n\(graphResult.2)\n", stderr)
    exit(1)
}

let root: DependencyNode
do {
    root = try JSONDecoder().decode(DependencyNode.self, from: jsonData(graphResult.1))
} catch {
    fputs("Dependency graph JSON decode failed: \(error)\n", stderr)
    fputs(String(graphResult.1.prefix(6000)) + "\n", stderr)
    exit(1)
}

var packages: [DependencyNode] = []
var pending = root.dependencies
while let next = pending.popLast() {
    packages.append(next)
    pending.append(contentsOf: next.dependencies)
}

let rootURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let allPackages = [(root.identity, rootURL)] + packages.map {
    ($0.identity, URL(fileURLWithPath: $0.path, isDirectory: true))
}
var failures = 0
for (identity, url) in allPackages {
    let result = try run([swiftExecutable, "package", "--package-path", url.path, "describe", "--type", "json"])
    guard result.0 == 0 else {
        failures += 1
        print("FAIL \(identity): swift package describe exited \(result.0)")
        print(String(result.2.prefix(3000)))
        continue
    }
    do {
        _ = try decoder.decode(PackageDump.self, from: jsonData(result.1))
        print("OK   \(identity)")
    } catch {
        failures += 1
        print("FAIL \(identity) at \(url.path)")
        print("Decode error: \(error)")
        print("JSON excerpt:")
        print(String(result.1.prefix(12000)))
    }
}
if failures > 0 {
    fputs("\n\(failures) package description(s) failed to decode.\n", stderr)
    exit(1)
}
print("All \(allPackages.count) SwiftPM package descriptions decoded successfully.")
