import Foundation

/// Downloads the game show sound effects once and keeps them on the device, so they
/// play with no connection (bad signal, airplane mode) after the first download.
/// Anything that fails to download is retried the next time the app becomes active.
final class SoundDownloader {

    static let shared = SoundDownloader()

    /// The repo's Sounds folder, served by GitHub.
    private let baseURL = URL(string: "https://raw.githubusercontent.com/alexsmith922/buzzer/main/Sounds/")!

    private let fileManager: FileManager
    private let session: URLSession
    private let directory: URL
    private var inFlight: Set<String> = []

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        // Fail fast offline instead of waiting; the next launch retries.
        configuration.waitsForConnectivity = false
        session = URLSession(configuration: configuration)

        // Application Support survives until the app is deleted, unlike Caches,
        // which iOS can clear when storage runs low.
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = support.appendingPathComponent("DownloadedSounds", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        // The files can always be downloaded again, so keep them out of iCloud backups.
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var excludedDirectory = directory
        try? excludedDirectory.setResourceValues(resourceValues)
    }

    /// The saved file for `fileName`, or nil if it hasn't been downloaded yet.
    func localURL(for fileName: String) -> URL? {
        let url = directory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    /// Starts downloading every game show sound that isn't saved yet. Safe to call often:
    /// saved sounds and downloads already running are skipped.
    func downloadMissingSounds() {
        for sound in SoundEffect.classics {
            guard case .downloaded(let fileName) = sound.source,
                  localURL(for: fileName) == nil,
                  !inFlight.contains(fileName) else { continue }
            download(fileName)
        }
    }

    private func download(_ fileName: String) {
        inFlight.insert(fileName)
        let remoteURL = baseURL.appendingPathComponent(fileName)
        let destination = directory.appendingPathComponent(fileName)

        let task = session.downloadTask(with: remoteURL) { [weak self] temporaryURL, response, error in
            guard let self else { return }
            // The temporary file is deleted when this handler returns, so move it now.
            var saved = false
            if let temporaryURL, error == nil,
               let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                do {
                    try? self.fileManager.removeItem(at: destination)
                    try self.fileManager.moveItem(at: temporaryURL, to: destination)
                    saved = true
                } catch {
                    print("Couldn't save \(fileName): \(error)")
                }
            }

            DispatchQueue.main.async {
                self.inFlight.remove(fileName)
                if saved {
                    SoundLibrary.shared.downloadedSoundsDidChange()
                }
            }
        }
        task.resume()
    }
}
