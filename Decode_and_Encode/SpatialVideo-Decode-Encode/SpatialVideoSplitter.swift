//
//  SpatialVideoSplitter.swift
//  SpatialVideo-Decode-Encode
//
//  Copyright (c) TikTok Pte. Ltd. All rights reserved. Licensed under the MIT license.
//  See LICENSE in the project root for license information.
//

import AVFoundation
import Foundation
import VideoToolbox
import Photos

public class SpatialVideoSplitter {
    
    let decoderOutputSettings: [String: Any] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_422YpCbCr8,
        AVVideoDecompressionPropertiesKey: [
            kVTDecompressionPropertyKey_RequestedMVHEVCVideoLayerIDs: [0, 1] as CFArray
        ],
    ]
    var completedFrames = 0
    
    public init() {}
    
    func incrementFrameCountAndLog() {
        completedFrames += 1
        print("\rencoded \(completedFrames) frames", terminator: "")
    }
    
    func getCurrentFrameCount() -> Int {
        return completedFrames
    }
    
    func createOutputUrl(outputFilename: String, outputDir: String?) throws -> URL {
        let outputDir = outputDir ?? FileManager.default.currentDirectoryPath
        let outputUrl = URL(fileURLWithPath: outputDir)
            .appendingPathComponent(outputFilename)
        if try !checkFileOverwrite(path: outputUrl.path()) {
            throw MediaError.createOutputError
        }
        print("output file set to \(outputUrl)")
        return outputUrl
    }
    
    func initWriter(outputUrl: URL, outputWidth: Int, outputHeight: Int) -> (
        AVAssetWriter, AVAssetWriterInputPixelBufferAdaptor
    ) {
        let assetWriter = try! AVAssetWriter(
            outputURL: outputUrl,
            fileType: .mov
        )
        
        let assetWriterInput = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.proRes422HQ,
                AVVideoWidthKey: outputWidth,
                AVVideoHeightKey: outputHeight,
                AVVideoColorPropertiesKey: [
                    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2
                ]
            ]
        )
        
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_422YpCbCr8,
            kCVPixelBufferWidthKey as String: outputWidth,
            kCVPixelBufferHeightKey as String: outputHeight
        ]
        
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: assetWriterInput,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        assetWriter.add(assetWriterInput)
        assetWriter.startWriting()
        assetWriter.startSession(atSourceTime: .zero)
        return (assetWriter, adaptor)
    }
    
    func extractMetadata(from url: URL) -> [String: Any] {
        let asset = AVAsset(url: url)
        var metadataDict: [String: Any] = [:]
        
        // Extract general metadata
        for item in asset.metadata {
            if let key = item.key as? String, let value = item.value {
                metadataDict[key] = value
            }
        }
        
        // Extract format description metadata
        if let videoTrack = asset.tracks(withMediaType: .video).first,
           let formatDescription = videoTrack.formatDescriptions.first {
            if let extensionsDictionary = CMFormatDescriptionGetExtensions(formatDescription as! CMFormatDescription) as? [String: Any] {
                metadataDict["formatDescriptionExtensions"] = extensionsDictionary
            }
        }
        
        // Extract track-specific metadata
        for track in asset.tracks {
            if let trackMetadata = extractTrackMetadata(from: track) {
                metadataDict["track_\(track.trackID)"] = trackMetadata
            }
        }
        
        return metadataDict
    }

    func extractTrackMetadata(from track: AVAssetTrack) -> [String: Any]? {
        var trackMetadata: [String: Any] = [:]
        
        trackMetadata["mediaType"] = track.mediaType.rawValue
        trackMetadata["naturalSize"] = NSCoder.string(for: track.naturalSize)
        trackMetadata["preferredTransform"] = NSCoder.string(for: track.preferredTransform)
        
        if let formatDescription = track.formatDescriptions.first {
            if let extensions = CMFormatDescriptionGetExtensions(formatDescription as! CMFormatDescription) as? [String: Any] {
                trackMetadata["formatDescriptionExtensions"] = extensions
            }
        }
        
        return trackMetadata.isEmpty ? nil : trackMetadata
    }
    
    func extractDimensions(sampleBuffer: CMSampleBuffer) throws -> (Int, Int) {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) else {
            // Handle error: format description not available
            throw MediaError.couldNotParse
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(formatDesc)
        let width = dimensions.width
        let height = dimensions.height
        
        return (Int(width), Int(height))
    }
    
    func processSample(
        sampleBuffer: CMSampleBuffer, leftAdaptor: AVAssetWriterInputPixelBufferAdaptor,
        rightAdaptor: AVAssetWriterInputPixelBufferAdaptor
    ) {
        let presentationTs = sampleBuffer.presentationTimeStamp
        let sampleBuffer_var = sampleBuffer
        guard let taggedBuffers = sampleBuffer.taggedBuffers else { return }
        let leftEyeBuffer = taggedBuffers.first(where: {
            $0.tags.first(matchingCategory: .stereoView) == .stereoView(.leftEye)
        })?.buffer
        let rightEyeBuffer =
        taggedBuffers.first(where: {
            $0.tags.first(matchingCategory: .stereoView) == .stereoView(.rightEye)
        })?.buffer
        
        if let leftEyeBuffer,
           let rightEyeBuffer,
           case let .pixelBuffer(leftEyePixelBuffer) = leftEyeBuffer,
           case let .pixelBuffer(rightEyePixelBuffer) = rightEyeBuffer
        {
            while !leftAdaptor.assetWriterInput.isReadyForMoreMediaData {
                // waiting
            }
            leftAdaptor.append(leftEyePixelBuffer, withPresentationTime: presentationTs)
            while !rightAdaptor.assetWriterInput.isReadyForMoreMediaData {
                // waiting...
            }
            rightAdaptor.append(rightEyePixelBuffer, withPresentationTime: presentationTs)
            incrementFrameCountAndLog()
        }
    }
    
    func checkFileOverwrite(path: String) throws -> Bool {
        
        if !FileManager.default.fileExists(atPath: path) {
            return true
        }
        
        print("File already exists: \(path)")
        print("Overwrite existing file? [y/N]: ", terminator: "")
        
        guard let userInput = readLine() else {
            print("aborting!")
            return false
        }
        
        if userInput.caseInsensitiveCompare("y") == .orderedSame {
            try FileManager.default.removeItem(atPath: path)
            return true
        } else {
            print("aborting!")
            return false
        }
    }
    
    func initReader(sourceUrl: URL) throws -> (AVAssetReader, AVAssetReaderTrackOutput) {
        let semaphore = DispatchSemaphore(value: 0)
        let sourceMovieAsset = AVURLAsset(url: sourceUrl)
        
        var tracks: [AVAssetTrack]?
        sourceMovieAsset.loadTracks(
            withMediaType: .video,
            completionHandler: { (foundtracks, error) in
                tracks = foundtracks
                semaphore.signal()
            })
        
        let loadingTimeoutResult = semaphore.wait(timeout: .now() + 60 * 60 * 24)
        switch loadingTimeoutResult {
        case .success:
            print("loaded video track")
        case .timedOut:
            print("loading video track exceeded hardcoded limit of 24 hours")
        }
        
        guard let tracks = tracks else {
            print("could not load any tracks!")
            throw MediaError.noVideoTracksFound
        }
        let assetReaderTrackOutput = AVAssetReaderTrackOutput(
            track: tracks.first!,
            outputSettings: decoderOutputSettings
        )
        assetReaderTrackOutput.alwaysCopiesSampleData = false
        let assetReader = try AVAssetReader(asset: sourceMovieAsset)
        assetReader.add(assetReaderTrackOutput)
        return (assetReader, assetReaderTrackOutput)
    }
    
    public func transcodeMovie(filePath: String, outputDir: String?) {
        do {
            let sourceMovieUrl = URL(fileURLWithPath: filePath)
            let inputFileExtension = sourceMovieUrl.pathExtension
            let inputFilename = sourceMovieUrl.lastPathComponent
            let basename = inputFilename.dropLast(inputFileExtension.count + 1)
            
            let (assetReader, assetReaderTrackOutput) = try initReader(sourceUrl: sourceMovieUrl)
            
            if !assetReader.startReading() {
                print("could not start reading")
                return
            }
            
            let inputSize = assetReaderTrackOutput.track.naturalSize
            let width = Int(inputSize.width)
            let height = Int(inputSize.height)
            
            let leftUrl = try createOutputUrl(
                outputFilename: basename + "_LEFT.mov", outputDir: outputDir)
            let rightUrl = try createOutputUrl(
                outputFilename: basename + "_RIGHT.mov", outputDir: outputDir)
            
            let (leftWriter, leftAdaptor) = initWriter(
                outputUrl: leftUrl, outputWidth: width, outputHeight: height)
            let (rightWiter, rightAdaptor) = initWriter(
                outputUrl: rightUrl, outputWidth: width, outputHeight: height)
            
            let semaphore = DispatchSemaphore(value: 0)
            
            while assetReader.status == .reading {
                guard let nextSampleBuffer = assetReaderTrackOutput.copyNextSampleBuffer() else {
                    if assetReader.status == .completed {
                        print("\nfinished reading all of \(filePath)")
                    } else {
                        print("\nadvancing due to null sample, reader status is \(assetReader.status)")
                    }
                    leftAdaptor.assetWriterInput.markAsFinished()
                    rightAdaptor.assetWriterInput.markAsFinished()
                    semaphore.signal()
                    continue
                }
                processSample(
                    sampleBuffer: nextSampleBuffer, leftAdaptor: leftAdaptor, rightAdaptor: rightAdaptor)
            }
            
            let encodingTimeoutResult = semaphore.wait(timeout: .now() + 60 * 60 * 24)
            switch encodingTimeoutResult {
            case .success:
                print("finished encoding, flushing bytes to disk... ")
            case .timedOut:
                print("encoding file processing time exceeded hardcoded limit of 24 hours")
            }
            
            leftWriter.finishWriting {
                semaphore.signal()
            }
            rightWiter.finishWriting {
                semaphore.signal()
            }
            var writingTimeoutResult = semaphore.wait(timeout: .now() + 60 * 60 * 24)
            switch writingTimeoutResult {
            case .success:
                print("finished writing one file")
            case .timedOut:
                print("writing file processing time exceeded hardcoded limit of 24 hours")
                throw MediaError.timeoutError
            }
            
            writingTimeoutResult = semaphore.wait(timeout: .now() + 60 * 60 * 24)
            switch writingTimeoutResult {
            case .success:
                print("finished writing both files")
            case .timedOut:
                print("writing second file processing time exceeded hardcoded limit of 24 hours")
                throw MediaError.timeoutError
            }
        } catch {
            print("Unexpected error: \(error).")
        }
    }
    
    private func saveToPhotoLibrary(leftUrl: URL, rightUrl: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("Photo library access not authorized")
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                // Create asset creation requests for left and right videos
                let leftCreationRequest = PHAssetCreationRequest.forAsset()
                leftCreationRequest.addResource(with: .video, fileURL: leftUrl, options: nil)
                
                let rightCreationRequest = PHAssetCreationRequest.forAsset()
                rightCreationRequest.addResource(with: .video, fileURL: rightUrl, options: nil)
            }) { success, error in
                if success {
                    print("Successfully saved videos to photo library")
                    // Optionally, you can delete the temporary files here
                    try? FileManager.default.removeItem(at: leftUrl)
                    try? FileManager.default.removeItem(at: rightUrl)
                } else if let error = error {
                    print("Error saving videos to photo library: \(error.localizedDescription)")
                }
            }
        }
    }


}
