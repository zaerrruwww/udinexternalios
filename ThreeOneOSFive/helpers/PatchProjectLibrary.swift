import Foundation

struct PatchLibraryItem: Identifiable {
    let summary: PatchPackageSummary
    var project: PatchProject?
    var contentKey: Data?
    var packageURL: URL

    var id: UUID { summary.packageID }
    var isLocked: Bool { project == nil }
    var displayName: String {
        let filename = packageURL.deletingPathExtension().lastPathComponent
        if filename.hasPrefix("OGIOS File (") {
            return filename
        }
        return project?.name ?? filename
    }
    var workspaceURL: URL? {
        PatchWorkspaceService.workspaceURL(projectID: id)
    }
}

struct PatchPasswordRequest: Identifiable {
    let summary: PatchPackageSummary
    var id: UUID { summary.packageID }
}

enum PatchProjectLibrary {
    static func packageRootURL(fileManager: FileManager = .default) throws -> URL {
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = base.appendingPathComponent("PatchProjects", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func backupRootURL(fileManager: FileManager = .default) throws -> URL {
        let root = try packageRootURL(fileManager: fileManager)
            .appendingPathComponent("Backups", isDirectory: true)
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func bundledPackageURLs(bundle: Bundle = .main, fileManager: FileManager = .default) -> [URL] {
        var sourceCandidates: [URL] = []
        for ext in ["3105", "OGIOS", "ogios"] {
            if let urls = bundle.urls(forResourcesWithExtension: ext, subdirectory: "Patches") {
                sourceCandidates.append(contentsOf: urls)
            }
            if let urls = bundle.urls(forResourcesWithExtension: ext, subdirectory: nil) {
                sourceCandidates.append(contentsOf: urls)
            }
        }
        let patchesDir = bundle.bundleURL.appendingPathComponent("Patches", isDirectory: true)
        if let dirContents = try? fileManager.contentsOfDirectory(at: patchesDir, includingPropertiesForKeys: nil) {
            sourceCandidates.append(contentsOf: dirContents.filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "3105" || ext == "ogios"
            })
        }
        if let resDir = bundle.resourceURL,
           let dirContents = try? fileManager.contentsOfDirectory(at: resDir, includingPropertiesForKeys: nil) {
            sourceCandidates.append(contentsOf: dirContents.filter {
                let ext = $0.pathExtension.lowercased()
                return ext == "3105" || ext == "ogios"
            })
        }

        var seen = Set<String>()
        return sourceCandidates.filter { seen.insert($0.standardizedFileURL.path).inserted }
    }

    static func installBundledPackagesIfNeeded(
        bundle: Bundle = .main,
        fileManager: FileManager = .default
    ) {
        guard let root = try? packageRootURL(fileManager: fileManager) else {
            return
        }

        let bundledURLs = bundledPackageURLs(bundle: bundle, fileManager: fileManager)

        for sourceURL in bundledURLs {
            let destinationURL = root.appendingPathComponent(sourceURL.lastPathComponent)
            do {
                let data = try Data(contentsOf: sourceURL, options: .mappedIfSafe)
                _ = try PatchPackageCodec.inspect(data)
                try data.write(to: destinationURL, options: [.atomic, .completeFileProtection])
                log("patch: installed bundled package \(sourceURL.lastPathComponent)")
            } catch {
                log("patch: skipped bundled package \(sourceURL.lastPathComponent): \(error)")
            }
        }
    }

    static func load(fileManager: FileManager = .default) -> [PatchLibraryItem] {
        var candidateURLs: [URL] = []
        if let root = try? packageRootURL(fileManager: fileManager),
           let urls = try? fileManager.contentsOfDirectory(
             at: root,
             includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
             options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
           ) {
            candidateURLs.append(contentsOf: urls)
        }
        candidateURLs.append(contentsOf: bundledPackageURLs(fileManager: fileManager))

        var byID: [UUID: PatchLibraryItem] = [:]
        var byFilename: [String: PatchLibraryItem] = [:]
        let validExtensions: Set<String> = ["3105", "ogios"]
        for url in candidateURLs where validExtensions.contains(url.pathExtension.lowercased()) {
            let filename = url.lastPathComponent.lowercased()
            if byFilename[filename] != nil { continue }
            do {
                let data = try readPackage(at: url)
                let summary = try PatchPackageCodec.inspect(data)
                let decoded: DecodedPatchPackage?
                if let contentKey = try PatchKeyStore.load(for: summary) {
                    decoded = try PatchPackageCodec.decode(data, contentKey: contentKey)
                } else if summary.isPasswordProtected {
                    // Only the app's bundled resources use the internal key
                    do {
                        let bundled = try PatchPackageCodec.decode(
                            data,
                            password: PatchPackageCodec.bundledResourcePassword
                        )
                        try PatchKeyStore.store(bundled.contentKey, for: summary)
                        decoded = bundled
                    } catch {
                        decoded = nil
                    }
                } else {
                    decoded = try PatchPackageCodec.decode(data, password: nil)
                }
                let item = PatchLibraryItem(
                    summary: summary,
                    project: decoded?.project,
                    contentKey: decoded?.contentKey,
                    packageURL: url
                )
                if summary.schemaVersion >= 2, let project = decoded?.project {
                    do {
                        _ = try PatchWorkspaceService.ensureWorkspace(for: project)
                    } catch {
                        log("patch: workspace unavailable for \(project.id.uuidString)")
                    }
                }
                byID[summary.packageID] = item
                byFilename[filename] = item
            } catch {
                log("patch: skipped invalid local package \(url.lastPathComponent): \(error)")
            }
        }
        return Array(byID.values).sorted {
            ($0.project?.updatedAt ?? .distantPast) > ($1.project?.updatedAt ?? .distantPast)
        }
    }

    static func loadDirect(named packageFilename: String, fileManager: FileManager = .default) -> PatchLibraryItem? {
        let bundled = bundledPackageURLs(fileManager: fileManager)
        let targetBase = (packageFilename as NSString).deletingPathExtension.lowercased()
        for url in bundled {
            let name = url.lastPathComponent
            let base = (name as NSString).deletingPathExtension.lowercased()
            if name.caseInsensitiveCompare(packageFilename) == .orderedSame || base == targetBase {
                do {
                    let data = try readPackage(at: url)
                    let summary = try PatchPackageCodec.inspect(data)
                    let decoded = try? PatchPackageCodec.decode(data, password: nil)
                    return PatchLibraryItem(
                        summary: summary,
                        project: decoded?.project,
                        contentKey: decoded?.contentKey,
                        packageURL: url
                    )
                } catch {
                    continue
                }
            }
        }
        return nil
    }

    static func readPackage(at url: URL) throws -> Data {
        let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey])
        guard values.isDirectory != true,
              values.isSymbolicLink != true,
              values.isRegularFile == true else {
            throw PatchPackageError.invalidProject
        }
        return try Data(contentsOf: url, options: .mappedIfSafe)
    }

    static func save(
        data: Data,
        projectName: String,
        existingURL: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let destination: URL
        if let existingURL {
            destination = existingURL
        } else {
            let root = try packageRootURL(fileManager: fileManager)
            let baseName = sanitizedFilename(projectName)
            var candidate = root.appendingPathComponent(baseName).appendingPathExtension("OGIOS")
            var suffix = 2
            while fileManager.fileExists(atPath: candidate.path) {
                candidate = root.appendingPathComponent("\(baseName)-\(suffix)").appendingPathExtension("OGIOS")
                suffix += 1
            }
            destination = candidate
        }
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }

    static func installImportedPackage(
        data: Data,
        decoded: DecodedPatchPackage,
        summary: PatchPackageSummary,
        existingURL: URL?,
        fileManager: FileManager = .default
    ) throws {
        let previousData = try existingURL.map { try readPackage(at: $0) }
        var savedURL: URL?
        do {
            savedURL = try save(
                data: data,
                projectName: decoded.project.name,
                existingURL: existingURL,
                fileManager: fileManager
            )
            if summary.schemaVersion >= 2 {
                _ = try PatchWorkspaceService.replaceWorkspace(
                    with: decoded.project,
                    fileManager: fileManager
                )
            } else {
                try? PatchWorkspaceService.deleteWorkspace(
                    projectID: decoded.project.id,
                    fileManager: fileManager
                )
            }
        } catch {
            if let previousData, let existingURL {
                try? previousData.write(
                    to: existingURL,
                    options: [.atomic, .completeFileProtection]
                )
            } else if let savedURL, fileManager.fileExists(atPath: savedURL.path) {
                try? fileManager.removeItem(at: savedURL)
            }
            throw error
        }
    }

    static func delete(_ item: PatchLibraryItem, fileManager: FileManager = .default) throws {
        if fileManager.fileExists(atPath: item.packageURL.path) {
            try fileManager.removeItem(at: item.packageURL)
        }
        try? PatchWorkspaceService.deleteWorkspace(projectID: item.id, fileManager: fileManager)
        try? PatchKeyStore.delete(for: item.summary)
    }

    static func synchronizeWorkspace(
        item: PatchLibraryItem,
        fileManager: FileManager = .default
    ) throws -> PatchProject {
        guard item.summary.schemaVersion >= 2,
              let baseProject = item.project,
              let contentKey = item.contentKey else {
            throw PatchPackageError.invalidProject
        }
        let workspace = try PatchWorkspaceService.ensureWorkspace(
            for: baseProject,
            fileManager: fileManager
        )
        let project = try PatchWorkspaceService.snapshot(
            baseProject: baseProject,
            workspaceURL: workspace,
            fileManager: fileManager
        )
        let original = try readPackage(at: item.packageURL)
        let updated = try PatchPackageCodec.update(
            original,
            project: project,
            contentKey: contentKey,
            schemaVersion: PatchPackageCodec.latestSchemaVersion
        )
        _ = try save(
            data: updated,
            projectName: project.name,
            existingURL: item.packageURL,
            fileManager: fileManager
        )
        return project
    }

    private static func sanitizedFilename(_ rawName: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let scalars = rawName.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let result = String(scalars)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(80)
        return result.isEmpty ? "Patch" : String(result)
    }
}
