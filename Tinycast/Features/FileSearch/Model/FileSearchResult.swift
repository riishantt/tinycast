import Foundation

struct FileSearchResult: Identifiable, Equatable, Sendable {
    let id: String
    let url: URL
    let name: String
    let parentPath: String
    /// The enclosing folder's own name, which is what tells two same-named folders apart.
    let parentName: String
    let isDirectory: Bool
    let modified: Date?

    /// `url` is taken as given: index paths are already real, and standardizing one costs a stat.
    init(url: URL, isDirectory: Bool, mtime: UInt32, homeDirectory: URL) {
        let parent = url.deletingLastPathComponent()
        self.id = url.path
        self.url = url
        self.name = url.lastPathComponent
        self.parentPath = Self.abbreviate(
            parent.path, homePath: homeDirectory.path)
        self.parentName = parent.lastPathComponent
        self.isDirectory = isDirectory
        // The index stores 0 for a crawl root, whose date it never read.
        self.modified = mtime == 0 ? nil : Date(timeIntervalSince1970: TimeInterval(mtime))
    }

    private static func abbreviate(_ path: String, homePath: String) -> String {
        if path == homePath { return "~" }
        guard path.hasPrefix(homePath + "/") else { return path }
        return "~" + path.dropFirst(homePath.count)
    }
}
