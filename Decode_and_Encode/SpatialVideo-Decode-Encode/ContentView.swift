import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var isShowingFolderPicker = false
    @State private var selectedFolder: URL?
    @State private var message = "No folder selected"
    @State private var videoFiles: [URL] = []
    @State private var isProcessing = false
    @State private var progress: Double = 0

    var body: some View {
        VStack {
            Text(message)
                .padding()

            Button("Select Folder") {
                isShowingFolderPicker = true
            }
            .padding()

            Button("Process Videos") {
                processVideos()
            }
            .disabled(selectedFolder == nil || isProcessing)
            .padding()

            if isProcessing {
                ProgressView("Processing", value: progress, total: 1.0)
                    .padding()
            }
        }
        .sheet(isPresented: $isShowingFolderPicker) {
            DocumentPicker(selectedFolder: $selectedFolder)
        }
    }

    func processVideos() {
        guard let folder = selectedFolder else {
            print("No folder selected")
            return
        }
        isProcessing = true
        message = "Processing videos in folder: \(folder.lastPathComponent)"
        print("Full folder path: \(folder.path)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let fileManager = FileManager.default
                let contents = try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles])
                
                let videos = contents.filter { $0.pathExtension.lowercased() == "mov" }
                let totalVideos = videos.count
                
                for (index, videoURL) in videos.enumerated() {
                    try processVideo(at: videoURL, folder: folder)
                    DispatchQueue.main.async {
                        self.progress = Double(index + 1) / Double(totalVideos)
                        self.message = "Processed \(index + 1) of \(totalVideos) videos"
                    }
                }
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.message = "Finished processing \(totalVideos) videos"
                    self.progress = 1.0
                }
            } catch {
                DispatchQueue.main.async {
                    self.message = "Error: \(error.localizedDescription)"
                    self.isProcessing = false
                    print("Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func processVideo(at inputURL: URL, folder: URL) throws {
        let splitter = SpatialVideoSplitter()
        let merger = SpatialVideoMerger()
        
        // Split the video
        let tempDir = FileManager.default.temporaryDirectory
        splitter.transcodeMovie(filePath: inputURL.path, outputDir: tempDir.path)
        
        let leftURL = tempDir.appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent + "_LEFT.mov")
        let rightURL = tempDir.appendingPathComponent(inputURL.deletingPathExtension().lastPathComponent + "_RIGHT.mov")
        
        let originalMetadata = splitter.extractMetadata(from: inputURL)
        
        let bitRates = [6_000_000, 2_000_000, 500_000]
        let keyFrameIntervals = [30, 120]
        let bFrameCounts = [0, 1]
        
        for bitRate in bitRates {
            for keyFrameInterval in keyFrameIntervals {
                for bFrameCount in bFrameCounts {
                    let outputFileName = "\(inputURL.deletingPathExtension().lastPathComponent)_re-encoded_\(bitRate)_\(keyFrameInterval)_\(bFrameCount).mov"
                    let outputURL = folder.appendingPathComponent(outputFileName)
                    
                    merger.transcodeMovie(
                        leftFilePath: leftURL.path,
                        rightFilePath: rightURL.path,
                        outputFilePath: outputURL.path,
                        quality: 1.0,
                        horizontalFieldOfView: 80,
                        horizontalDisparityAdjustment: 0.2,
                        leftIsPrimary: false,
                        requiredBitRate: bitRate,
                        keyFrameInterval: keyFrameInterval,
                        numBFrames: bFrameCount,
                        originalMetadata: originalMetadata
                    )
                }
            }
        }
        
        // Clean up temporary files
        try? FileManager.default.removeItem(at: leftURL)
        try? FileManager.default.removeItem(at: rightURL)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFolder: URL?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            print("Selected folder URL: \(url)")
            parent.selectedFolder = url
            
            // Access the security-scoped resource
            if url.startAccessingSecurityScopedResource() {
                // We're not stopping access here because we need to keep access for later use
                print("Successfully accessed the folder")
            } else {
                url.stopAccessingSecurityScopedResource()
                print("Failed to access the folder")
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

enum MediaError: Error {
    case invalidMediaInput
    case noVideoTracksFound
    case couldNotReadSample
    case couldNotParse
    case timeoutError
    case createOutputError
    case inputTimestampMismatch
    case appendTaggedBufferError
}
