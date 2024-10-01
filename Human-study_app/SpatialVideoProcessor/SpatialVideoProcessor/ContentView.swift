//
//  ContentView.swift
//  SpatialVideoProcessor
//
//  Copyright (c) TikTok Pte. Ltd. All rights reserved. Licensed under the MIT license.
//  See LICENSE in the project root for license information.
//

import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var inputFolderPath = ""
    @State private var isProcessing = false
    @State private var processingStatus = ""

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                TextField("Input Folder", text: $inputFolderPath)
                Button("Select") {
                    inputFolderPath = selectFolder()
                }
            }
            Button("Process Videos") {
                processVideos()
            }
            .disabled(inputFolderPath.isEmpty || isProcessing)
            Text(processingStatus)
        }
        .padding()
        .frame(width: 400, height: 200)
    }

    func selectFolder() -> String {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        if panel.runModal() == .OK {
            return panel.url?.path ?? ""
        }
        return ""
    }

    func processVideos() {
        isProcessing = true
        processingStatus = "Processing videos..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            let processor = VideoProcessor()
            processor.processVideos(in: inputFolderPath) { status in
                DispatchQueue.main.async {
                    processingStatus = status
                }
            }
            DispatchQueue.main.async {
                isProcessing = false
                processingStatus = "Processing complete. Check your Documents folder for the output."
            }
        }
    }
}

class VideoProcessor {
    let splitter = SpatialVideoSplitter()
    
    func processVideos(in inputFolder: String, statusUpdate: @escaping (String) -> Void) {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(atPath: inputFolder) else {
            statusUpdate("Failed to access input folder")
            return
        }
        
        var processedCount = 0
        var totalCount = 0
        
        while let filePath = enumerator.nextObject() as? String {
            guard filePath.lowercased().hasSuffix(".mov") else { continue }
            totalCount += 1
            
            let inputURL = URL(fileURLWithPath: inputFolder).appendingPathComponent(filePath)
            let outputFilename = filePath.replacingOccurrences(of: ".MOV", with: "_SBS.mov", options: .caseInsensitive)
                .replacingOccurrences(of: ".mov", with: "_SBS.mov")
            
            statusUpdate("Processing \(filePath) (\(processedCount + 1)/\(totalCount))")
            
            autoreleasepool {
                do {
                    try processSingleVideo(inputURL: inputURL, outputFilename: outputFilename)
                    processedCount += 1
                    statusUpdate("Successfully processed \(filePath) (\(processedCount)/\(totalCount))")
                } catch {
                    statusUpdate("Error processing \(filePath): \(error.localizedDescription)")
                }
            }
            
            // Force memory cleanup
            autoreleasepool { }
        }
        
        statusUpdate("Completed processing \(processedCount) out of \(totalCount) videos")
    }
    
    func processSingleVideo(inputURL: URL, outputFilename: String) throws {
        let tempDir = FileManager.default.temporaryDirectory
        splitter.transcodeMovie(filePath: inputURL.path, outputDir: tempDir.path)
        
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let leftURL = tempDir.appendingPathComponent(baseName + "_LEFT.mov")
        let rightURL = tempDir.appendingPathComponent(baseName + "_RIGHT.mov")
        
        try stitchSideBySide(leftURL: leftURL, rightURL: rightURL, outputFilename: outputFilename)
        
        try FileManager.default.removeItem(at: leftURL)
        try FileManager.default.removeItem(at: rightURL)
    }
    
    func stitchSideBySide(leftURL: URL, rightURL: URL, outputFilename: String) throws {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let outputURL = documentsDirectory.appendingPathComponent(outputFilename)
        
        var processingError: Error?
        
        autoreleasepool {
            do {
                let leftAsset = AVAsset(url: leftURL)
                let rightAsset = AVAsset(url: rightURL)
                
                guard let leftTrack = leftAsset.tracks(withMediaType: .video).first,
                      let rightTrack = rightAsset.tracks(withMediaType: .video).first else {
                    throw NSError(domain: "VideoProcessor", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find video tracks"])
                }
                
                let composition = AVMutableComposition()
                let videoComposition = AVMutableVideoComposition()
                
                guard let leftCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
                      let rightCompositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                    throw NSError(domain: "VideoProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create composition tracks"])
                }
                
                let duration = min(leftAsset.duration, rightAsset.duration)
                let trimmedDuration = CMTimeMultiply(CMTime(seconds: 10, preferredTimescale: duration.timescale), multiplier: 1)
                let timeRange = CMTimeRange(start: .zero, duration: min(duration, trimmedDuration))
                
                try leftCompositionTrack.insertTimeRange(timeRange, of: leftTrack, at: .zero)
                try rightCompositionTrack.insertTimeRange(timeRange, of: rightTrack, at: .zero)
                
                let instruction = AVMutableVideoCompositionInstruction()
                instruction.timeRange = timeRange
                
                let leftLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: leftCompositionTrack)
                let rightLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: rightCompositionTrack)
                
                let renderSize = CGSize(width: leftTrack.naturalSize.width * 2, height: leftTrack.naturalSize.height)
                let transform = CGAffineTransform(translationX: leftTrack.naturalSize.width, y: 0)
                rightLayerInstruction.setTransform(transform, at: .zero)
                
                instruction.layerInstructions = [leftLayerInstruction, rightLayerInstruction]
                videoComposition.instructions = [instruction]
                videoComposition.renderSize = renderSize
                videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
                
                guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHEVCHighestQuality) else {
                    throw NSError(domain: "VideoProcessor", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
                }
                exportSession.videoComposition = videoComposition
                exportSession.outputURL = outputURL
                exportSession.outputFileType = .mov
                
                let semaphore = DispatchSemaphore(value: 0)
                exportSession.exportAsynchronously {
                    if let error = exportSession.error {
                        processingError = error
                    }
                    semaphore.signal()
                }
                semaphore.wait()
                
                if let error = processingError {
                    throw error
                }
            } catch {
                processingError = error
            }
        }
        
        if let error = processingError {
            throw error
        }
    }
}
