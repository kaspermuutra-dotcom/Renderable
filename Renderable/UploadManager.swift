import Foundation
import Combine

class UploadManager: ObservableObject {

    static let baseURL = "http://172.20.10.6:5050"

    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var result: UploadResponse? = nil
    @Published var errorMessage: String? = nil

    func upload(fileURL: URL) {
        isUploading = true
        uploadProgress = 0
        result = nil
        errorMessage = nil

        guard let url = URL(string: "\(Self.baseURL)/scan/upload") else {
            errorMessage = "Invalid upload URL"
            isUploading = false
            return
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60

        // Build multipart body by streaming the zip to a temp file on a background
        // thread. This avoids loading the entire archive into RAM before upload.
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".multipart")

            guard self.streamMultipartBody(fileURL: fileURL, boundary: boundary, to: tempURL) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to prepare upload"
                    self.isUploading = false
                }
                return
            }

            let task = URLSession.shared.uploadTask(with: request, fromFile: tempURL) { [weak self] data, _, error in
                try? FileManager.default.removeItem(at: tempURL)
                DispatchQueue.main.async {
                    self?.isUploading = false

                    if let error = error {
                        self?.errorMessage = "Upload failed: \(error.localizedDescription)"
                        return
                    }

                    guard let data = data else {
                        self?.errorMessage = "No response from server"
                        return
                    }

                    do {
                        let decoded = try JSONDecoder().decode(UploadResponse.self, from: data)
                        self?.result = decoded
                    } catch {
                        let raw = String(data: data, encoding: .utf8) ?? "unreadable"
                        self?.errorMessage = "Decode error — raw response: \(raw)"
                    }
                }
            }
            task.resume()
        }
    }

    /// Streams the zip file into a multipart body written to a temp file in 64 KB chunks.
    /// Returns false if any stream operation fails.
    private func streamMultipartBody(fileURL: URL, boundary: String, to destination: URL) -> Bool {
        let filename     = fileURL.lastPathComponent
        let headerString = "--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\nContent-Type: application/zip\r\n\r\n"
        let footerString = "\r\n--\(boundary)--\r\n"

        guard let headerData = headerString.data(using: .utf8),
              let footerData = footerString.data(using: .utf8),
              let out        = OutputStream(url: destination, append: false),
              let input      = InputStream(url: fileURL) else { return false }

        out.open()
        defer { out.close() }

        headerData.withUnsafeBytes { ptr in
            _ = out.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: headerData.count)
        }

        input.open()
        defer { input.close() }

        var buffer = [UInt8](repeating: 0, count: 65_536)
        while input.hasBytesAvailable {
            let n = input.read(&buffer, maxLength: buffer.count)
            guard n > 0 else { break }
            _ = out.write(buffer, maxLength: n)
        }

        footerData.withUnsafeBytes { ptr in
            _ = out.write(ptr.bindMemory(to: UInt8.self).baseAddress!, maxLength: footerData.count)
        }

        return true
    }
}

struct UploadResponse: Decodable {
    let scan_id: String
    let viewer_url: String
}
