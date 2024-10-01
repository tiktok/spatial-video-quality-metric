//
//  SpatialVideo_Decode_EncodeApp.swift
//  SpatialVideo-Decode-Encode
//
//  Copyright (c) TikTok Pte. Ltd. All rights reserved. Licensed under the MIT license.
//  See LICENSE in the project root for license information.
//

import SwiftUI

@main
struct SpatialVideo_Decode_EncodeApp: App {
    init() {
        cleanupTemporaryFiles()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
    
    func cleanupTemporaryFiles() {
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: tempDirectory, includingPropertiesForKeys: nil)
            for fileURL in fileURLs {
                if fileURL.pathExtension == "mov" {
                    try fileManager.removeItem(at: fileURL)
                    print("Deleted temporary file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Error cleaning up temporary files: \(error)")
        }
    }
}
