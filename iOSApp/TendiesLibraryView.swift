import SwiftUI
import UniformTypeIdentifiers
import SafariServices

struct TendiesLibraryView: View {
    @State private var files: [URL] = []
    @State private var importing = false
    @State private var browsing = false
    @State private var downloadURL = ""
    @State private var busy = false
    @State private var message: String?

    private let gallery = URL(string: "https://cowabun.ga/wallpapers")!
    private var directory: URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documents.appendingPathComponent("Tendies", isDirectory: true)
    }

    var body: some View {
        Form {
            Section("Cowabunga Wallpapers") {
                Button("Browse Wallpaper Gallery") { browsing = true }
                Text("Download a .tendies file in the gallery, then import it using Files.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section("Import Wallpapers") {
                Button("Import .tendies from Files") { importing = true }
                TextField("Direct HTTPS .tendies download URL", text: $downloadURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                Button(busy ? "Downloading…" : "Import from URL") {
                    Task { await importRemote() }
                }
                .disabled(busy || downloadURL.isEmpty)
            }
            Section("My Wallpapers") {
                if files.isEmpty {
                    Text("No wallpapers imported yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(files, id: \.self) { url in
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                        Spacer()
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            Section {
                Text("Importing files does not install a system wallpaper. Applying .tendies requires a compatible, separately implemented method.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Tendies Wallpapers")
        .onAppear(perform: refresh)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    guard url.pathExtension.lowercased() == "tendies" else {
                        message = "Only .tendies files are supported."
                        continue
                    }
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    do { try store(url) } catch { message = error.localizedDescription }
                }
                refresh()
            case .failure(let error): message = error.localizedDescription
            }
        }
        .sheet(isPresented: $browsing) {
            SafariView(url: gallery).ignoresSafeArea()
        }
        .alert("Tendies Library", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: {
            Text(message ?? "")
        }
    }

    private func refresh() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        files = ((try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension.lowercased() == "tendies" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    private func store(_ source: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let target = directory.appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent)
        try FileManager.default.copyItem(at: source, to: target)
    }

    private func importRemote() async {
        guard let url = URL(string: downloadURL),
              url.scheme == "https",
              url.pathExtension.lowercased() == "tendies" else {
            message = "Enter a direct HTTPS link ending in .tendies."
            return
        }
        busy = true
        defer { busy = false }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 30
            let (temp, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  response.url?.scheme == "https" else {
                message = "Download failed or redirected to an unsupported URL."
                return
            }
            let attrs = try FileManager.default.attributesOfItem(atPath: temp.path)
            guard let size = attrs[.size] as? NSNumber, size.int64Value <= 100_000_000 else {
                message = "File exceeds the 100 MB limit."
                return
            }
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(UUID().uuidString + "-" + url.lastPathComponent)
            try FileManager.default.copyItem(at: temp, to: destination)
            refresh()
            downloadURL = ""
            message = "Wallpaper imported successfully. Applying it to iOS is not yet supported."
        } catch {
            message = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { try? FileManager.default.removeItem(at: files[index]) }
        refresh()
    }
}

private struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
