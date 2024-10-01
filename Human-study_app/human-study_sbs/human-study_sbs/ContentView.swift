//
//  ContentView.swift
//  human-study_sbs
//
//  Copyright (c) TikTok Pte. Ltd. All rights reserved. Licensed under the MIT license.
//  See LICENSE in the project root for license information.
//

import SwiftUI
import UniformTypeIdentifiers

struct FolderSelectionView: View {
    @ObservedObject var studyManager: StudyManager
    @State private var isShowingDocumentPicker = false

    var body: some View {
        VStack {
            Text("Select Human-Study Folder")
            Button("Choose Folder") {
                isShowingDocumentPicker = true
            }
        }
        .sheet(isPresented: $isShowingDocumentPicker) {
            DocumentPicker(folderURL: $studyManager.studyFolder)
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var folderURL: URL?

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
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
            parent.folderURL = url
            
            // Grant permanent access to the selected folder
            let _ = url.startAccessingSecurityScopedResource()
        }
    }
}

//import SwiftUI
//
//struct StudySetupView: View {
//    @ObservedObject var studyManager: StudyManager
//
//    var body: some View {
//        VStack {
//            TextField("Subject ID (01-99)", text: $studyManager.subjectID)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//            TextField("Session ID (1 or 2)", text: $studyManager.sessionID)
//                .textFieldStyle(RoundedBorderTextFieldStyle())
//            Button("Start Study") {
//                studyManager.loadPlaylist()
//            }
//            .disabled(studyManager.subjectID.isEmpty || studyManager.sessionID.isEmpty)
//        }
//        .padding()
//    }
//}

import SwiftUI

struct StudySetupView: View {
    @ObservedObject var studyManager: StudyManager

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: geometry.size.width / 2)

                Divider()
                    .frame(width: 1, height: geometry.size.height)
                    .background(Color.black)

                VStack {
                    Spacer()
                    VStack(alignment: .center) {
                        TextField("Subject ID (01-99)", text: $studyManager.subjectID)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("Session ID (1 or 2)", text: $studyManager.sessionID)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button("Start Study") {
                            studyManager.loadPlaylist()
                        }
                        .disabled(studyManager.subjectID.isEmpty || studyManager.sessionID.isEmpty)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    Spacer()
                }
                .frame(width: geometry.size.width / 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .padding()
    }
}


//import SwiftUI
//import AVKit
//
//struct VideoPlayerView: View {
//    @ObservedObject var studyManager: StudyManager
//    @State private var showRatingView = false
//    @State private var player = AVPlayer()
//
//    var body: some View {
//        Group {
//            if studyManager.currentVideoIndex < studyManager.currentPlaylist.count {
//                if let videoURL = studyManager.videoURL(for: studyManager.currentPlaylist[studyManager.currentVideoIndex].filename) {
//                    if showRatingView {
//                        RatingView(studyManager: studyManager) {
//                            showRatingView = false
//                            studyManager.moveToNextVideo()
//                        }
//                    } else {
//                        PlayerView(player: player, videoURL: videoURL) {
//                            showRatingView = true
//                        }
//                    }
//                } else {
//                    Text("Error: Video not found")
//                }
//            } else {
//                StudyCompletionView()
//            }
//        }
//        .onChange(of: studyManager.currentVideoIndex) { _ in
//            showRatingView = false
//        }
//    }
//}

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    @ObservedObject var studyManager: StudyManager
    @State private var showRatingView = false
    @State private var player = AVPlayer()

    var body: some View {
        ZStack {
            if studyManager.currentVideoIndex < studyManager.currentPlaylist.count {
                if let videoURL = studyManager.videoURL(for: studyManager.currentPlaylist[studyManager.currentVideoIndex].filename) {
                    if showRatingView {
                        RatingView(studyManager: studyManager) {
                            showRatingView = false
                            studyManager.moveToNextVideo()
                        }
                    } else {
                        PlayerView(player: player, videoURL: videoURL) {
                            showRatingView = true
                        }
                    }
                } else {
                    Text("Error: Video not found")
                }
            } else {
                StudyCompletionView()
            }
        }
        .background(Color.black) // Ensure the background is black when the video is playing
        .onChange(of: studyManager.currentVideoIndex) { _ in
            showRatingView = false
        }
    }
}


//import SwiftUI
//import AVKit
//
//struct PlayerView: View {
//    @State private var player: AVPlayer
//    let videoURL: URL
//    let onCompletion: () -> Void
//
//    init(player: AVPlayer, videoURL: URL, onCompletion: @escaping () -> Void) {
//        self._player = State(initialValue: player)
//        self.videoURL = videoURL
//        self.onCompletion = onCompletion
//    }
//
//    var body: some View {
//        VideoPlayer(player: player)
//            .onAppear {
//                setupPlayer()
//            }
//            .onDisappear {
//                cleanupPlayer()
//            }
//    }
//
//    private func setupPlayer() {
//        let asset = AVAsset(url: videoURL)
//        let playerItem = AVPlayerItem(asset: asset)
//        player.replaceCurrentItem(with: playerItem)
//        player.play()
//
//        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
//            onCompletion()
//        }
//    }
//
//    private func cleanupPlayer() {
//        player.pause()
//        player.replaceCurrentItem(with: nil)
//        NotificationCenter.default.removeObserver(self)
//    }
//}

import SwiftUI
import AVKit

struct PlayerView: View {
    @State private var player: AVPlayer
    let videoURL: URL
    let onCompletion: () -> Void

    init(player: AVPlayer, videoURL: URL, onCompletion: @escaping () -> Void) {
        self._player = State(initialValue: player)
        self.videoURL = videoURL
        self.onCompletion = onCompletion
    }

    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                setupPlayer()
            }
            .onDisappear {
                cleanupPlayer()
            }
            .disabled(true) // Disable user interaction with the video player
            .background(Color.black) // Set the background to black
//            .edgesIgnoringSafeArea(.all) // Ensure it covers the entire screen
    }

    private func setupPlayer() {
        let asset = AVAsset(url: videoURL)
        let playerItem = AVPlayerItem(asset: asset)
        player.replaceCurrentItem(with: playerItem)
        player.play()

        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            onCompletion()
        }
    }

    private func cleanupPlayer() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        NotificationCenter.default.removeObserver(self)
    }
}




import SwiftUI

struct StudyCompletionView: View {
    var body: some View {
        Text("Study Complete. Thank you for participating!")
            .padding()
            .background(Color.white)
            .multilineTextAlignment(.center)
    }
}


import Foundation
import AVFoundation

class StudyManager: ObservableObject {
    @Published var studyFolder: URL? {
        didSet {
            if let url = studyFolder {
                let _ = url.startAccessingSecurityScopedResource()
            }
        }
    }
    @Published var subjectID: String = ""
    @Published var sessionID: String = ""
    @Published var currentPlaylist: [Video] = []
    @Published var currentVideoIndex: Int = 0
    @Published var ratings: [Int] = []
    @Published var isStudyStarted: Bool = false

    func loadPlaylist() {
        guard let studyFolder = studyFolder,
              let playlistURL = playlistURL(for: subjectID, sessionID: sessionID) else {
            print("Failed to get playlist URL")
            return
        }
        
        do {
            let csvContent = try String(contentsOf: playlistURL)
            let filenames = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }
            currentPlaylist = filenames.map { Video(filename: $0) }
            isStudyStarted = true
        } catch {
            print("Error loading playlist: \(error)")
        }
    }
    
    func playlistURL(for subjectID: String, sessionID: String) -> URL? {
        studyFolder?.appendingPathComponent("playlists/playlist_\(subjectID)_\(sessionID).csv")
    }
    
    func videoURL(for filename: String) -> URL? {
        studyFolder?.appendingPathComponent("videos/\(filename)")
    }
    
    func saveRating(_ rating: Int) {
        ratings.append(rating)
        
        guard let studyFolder = studyFolder else {
            print("Study folder is nil")
            return
        }
        let ratingsFolder = studyFolder.appendingPathComponent("ratings")
        let ratingsFile = ratingsFolder.appendingPathComponent("ratings_\(subjectID)_\(sessionID).csv")
        
        do {
            try FileManager.default.createDirectory(at: ratingsFolder, withIntermediateDirectories: true)
            let ratingsString = ratings.map { String($0) }.joined(separator: ",")
            try ratingsString.write(to: ratingsFile, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving ratings: \(error)")
        }
    }
    
    func moveToNextVideo() {
        currentVideoIndex += 1
        if currentVideoIndex >= currentPlaylist.count {
            print("Study completed")
        }
    }
    
    deinit {
        if let url = studyFolder {
            url.stopAccessingSecurityScopedResource()
        }
    }
}

struct Video: Identifiable {
    let id = UUID()
    let filename: String
}

import SwiftUI

struct ContentView: View {
    @StateObject private var studyManager = StudyManager()
    
    var body: some View {
        Group {
            if studyManager.studyFolder == nil {
                FolderSelectionView(studyManager: studyManager)
            } else if !studyManager.isStudyStarted {
                StudySetupView(studyManager: studyManager)
            } else {
                VideoPlayerView(studyManager: studyManager)
            }
        }
    }
}


//import SwiftUI
//
//struct RatingView: View {
//    @ObservedObject var studyManager: StudyManager
//    @State private var rating: Int = 0
//    var onCompletion: () -> Void
//
//    var body: some View {
//        GeometryReader { geometry in
//            HStack(spacing: 0) {
//                Spacer()
//                    .frame(width: geometry.size.width / 2)
//
//                Divider()
//                    .frame(width: 1, height: geometry.size.height)
//                    .background(Color.black)
//
//                VStack {
//                    Text("Rate the video quality")
//                    Slider(value: Binding(get: { Double(rating) }, set: { rating = Int($0) }), in: 0...100, step: 1)
//                    Text("Rating: \(rating)")
//                    Button("Submit") {
//                        studyManager.saveRating(rating)
//                        onCompletion()
//                    }
//                }
//                .padding()
//                .background(Color.white)
//                .frame(width: geometry.size.width / 2)
//            }
//            .frame(width: geometry.size.width, height: geometry.size.height)
//        }
//    }
//}

import SwiftUI

struct RatingView: View {
    @ObservedObject var studyManager: StudyManager
    @State private var rating: Double = 0
    var onCompletion: () -> Void

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                Spacer()
                    .frame(width: geometry.size.width / 2)

                Divider()
                    .frame(width: 1, height: geometry.size.height)
                    .background(Color.black)

                VStack {
                    Text("Rate the video quality")
                    CustomSlider(value: $rating, range: 0...100, step: 1) { _ in }
                    Text("Rating: \(Int(rating))")
                    Button("Submit") {
                        studyManager.saveRating(Int(rating))
                        onCompletion()
                    }
                }
                .padding()
                .background(Color.white)
                .frame(width: geometry.size.width / 2)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}



import SwiftUI

struct CustomSlider: UIViewRepresentable {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let onEditingChanged: (Bool) -> Void

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider(frame: .zero)
        slider.minimumValue = Float(range.lowerBound)
        slider.maximumValue = Float(range.upperBound)
        slider.value = Float(value)
        slider.addTarget(
            context.coordinator,
            action: #selector(Coordinator.valueChanged(_:)),
            for: .valueChanged
        )

        // Add tap gesture recognizer
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTapGesture(_:)))
        slider.addGestureRecognizer(tapGesture)
        
        return slider
    }

    func updateUIView(_ uiView: UISlider, context: Context) {
        uiView.value = Float(value)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(value: $value, step: step, onEditingChanged: onEditingChanged)
    }

    class Coordinator: NSObject {
        @Binding var value: Double
        let step: Double
        let onEditingChanged: (Bool) -> Void

        init(value: Binding<Double>, step: Double, onEditingChanged: @escaping (Bool) -> Void) {
            self._value = value
            self.step = step
            self.onEditingChanged = onEditingChanged
        }

        @objc func valueChanged(_ sender: UISlider) {
            let newValue = Double(sender.value)
            value = newValue
            onEditingChanged(true)
        }

        @objc func handleTapGesture(_ gestureRecognizer: UITapGestureRecognizer) {
            guard let slider = gestureRecognizer.view as? UISlider else { return }
            let point = gestureRecognizer.location(in: slider)
            let percentage = point.x / slider.bounds.width
            let newValue = Float(percentage) * (slider.maximumValue - slider.minimumValue) + slider.minimumValue
            slider.setValue(newValue, animated: true)
            value = Double(newValue)
            onEditingChanged(true)
        }
    }
}
