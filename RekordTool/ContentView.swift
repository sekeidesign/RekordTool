//
//  ContentView.swift
//  HotMemory
//
//  Created by Piergiorgio Gonni on 2024-11-29.
//

import AppKit
import RegexBuilder
import SwiftUI

// Helper Model
struct FileItem: Hashable {
    let url: URL
    var name: String { url.lastPathComponent }
    let isDirectory: Bool
    var children: [FileItem]? = nil

    // Conformance to Hashable
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
    }

    static func equality(lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.url == rhs.url
    }
}

struct FileSystemView: View {
    @State private var selectedFile: FileItem?
    @State private var isLoading: Bool = false
    @State private var totalHotCues: Int = 0
    @State private var convertedCues: Int = 0

    var body: some View {
        VStack(alignment: .center) {
            if let selectedFile = selectedFile {
                VStack {
                    VStack(spacing: 10) {
                        Text("Selected File")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text(selectedFile.name)
                            .font(.title)
                        Text("Path: \(selectedFile.url.path)")
                            .font(.caption2)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(.tertiary)
                        if isRekordboxCollection(file: selectedFile) {
                            HStack {
                                VStack {
                                    Text("Songs")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text("\(getSongCount(file: selectedFile))")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                RoundedRectangle(cornerRadius: 1)
                                    .frame(width: 1, height: 20)
                                    .foregroundColor(.gray.opacity(0.25))
                                VStack {
                                    Text("Hot cues")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text("\(getHotCueCount(file: selectedFile))")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                RoundedRectangle(cornerRadius: 1)
                                    .frame(width: 1, height: 20)
                                    .foregroundColor(.gray.opacity(0.25))
                                VStack {
                                    Text("Memory cues")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Text("\(getMemoryCueCount(file: selectedFile))")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemFill))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            if isLoading {
                                VStack {
                                    ProgressView(value: Double(convertedCues), total: Double(totalHotCues))
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .padding()
                                    Text("Converting \(convertedCues) of \(totalHotCues) hot cues...")
                                        .font(.caption)
                                }
                            }
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark.octagon")
                                Text("This file is not a Rekordbox collection, please select a different file.")
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(.systemFill))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    Button {
                        startConversion(for: selectedFile)
                    } label: {
                        Text("Convert Memory Cues to Hot Cues")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isRekordboxCollection(file: selectedFile) == false)
                    Button {
                        selectPlaylist()
                    } label: {
                        Text("Select collection")
                    }
                }
                .frame(minWidth: 200, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
                .padding()
            } else {
                VStack(spacing: 10) {
                    Text("No file selected")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("Select a valid Rekordbox collection")
                    Button {
                        selectPlaylist()
                    } label: {
                        Text("Select collection")
                    }
                }
                .frame(minWidth: 200, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
            }
        }
    }

    private func startConversion(for file: FileItem) {
        isLoading = true
        totalHotCues = getHotCueCount(file: file)
        convertedCues = 0

        DispatchQueue.global(qos: .userInitiated).async {
            convertMemoryCuesToHotCues(file: file) { progress in
                DispatchQueue.main.async {
                    self.convertedCues = progress
                }
            }
            DispatchQueue.main.async {
                isLoading = false
            }
        }
    }

    private func loadFile(url: URL) {
        selectedFile = FileItem(url: url, isDirectory: false)
    }

    private func selectPlaylist() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.xml]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK {
            if let url = panel.url {
                loadFile(url: url)
            }
        }
    }

    private func getSongCount(file: FileItem) -> Int {
        guard file.isDirectory == false else { return 0 }
        do {
            let contents = try String(contentsOf: file.url, encoding: .utf8)

            // Use Regex for matching "<NODE"
            let regex = /<\/TRACK>/
            let matches = contents.matches(of: regex)
            return matches.count
        } catch {
            print("Failed to read file contents: \(error)")
            return 0
        }
    }

    private func getMemoryCueCount(file: FileItem) -> Int {
        guard file.isDirectory == false else { return 0 }
        do {
            let contents = try String(contentsOf: file.url, encoding: .utf8)

            // Regex to match <POSITION_MARK ... Num="x" where x > -1
            let regex = /<POSITION_MARK[^>]*Num="(-?\d+)"/
            let matches = contents.matches(of: regex)

            // Filter matches where Num > -1
            let validMatches = matches.filter { match in
                let numString = String(match.output.1) // Convert Substring to String
                if let num = Int(numString), num == -1 {
                    return true
                }
                return false
            }

            return validMatches.count
        } catch {
            print("Failed to read file contents: \(error)")
            return 0
        }
    }

    private func getHotCueCount(file: FileItem) -> Int {
        guard file.isDirectory == false else { return 0 }
        do {
            let contents = try String(contentsOf: file.url, encoding: .utf8)

            // Regex to match <POSITION_MARK ... Num="x" where x > -1
            let regex = /<POSITION_MARK[^>]*Num="(-?\d+)"/
            let matches = contents.matches(of: regex)

            // Filter matches where Num > -1
            let validMatches = matches.filter { match in
                let numString = String(match.output.1) // Convert Substring to String
                if let num = Int(numString), num > -1 {
                    return true
                }
                return false
            }

            return validMatches.count
        } catch {
            print("Failed to read file contents: \(error)")
            return 0
        }
    }

    private func isRekordboxCollection(file: FileItem) -> Bool {
        guard file.isDirectory == false else { return false }
        do {
            let contents = try String(contentsOf: file.url, encoding: .utf8)
            return contents.contains("<PRODUCT Name=\"rekordbox\"") && contents.contains("<COLLECTION")
        } catch {
            print("Failed to read file contents: \(error)")
            return false
        }
    }

    private func convertMemoryCuesToHotCues(file: FileItem, progressCallback: @escaping (Int) -> Void) {
        guard let reader = StreamReader(url: file.url) else {
            print("Failed to open file for reading.")
            return
        }

        var modifiedLines = [String]()
        var processedCount = 0

        defer {
            reader.close()
        }

        while let line = reader.nextLine() {
            // Always add the original line
            modifiedLines.append(line)

            // Check if the line contains a <POSITION_MARK> with Num="x"
            if let matchRange = line.range(of: #"<POSITION_MARK[^>]*\bNum="(\d+)""#, options: .regularExpression) {
                let fullTag = String(line[matchRange])

                // Extract Num="x"
                if let numRange = fullTag.range(of: #"Num="\d+""#, options: .regularExpression) {
                    let numString = String(fullTag[numRange])
                        .replacingOccurrences(of: #"Num=""#, with: "")
                        .replacingOccurrences(of: "\"", with: "")

                    if let num = Int(numString), num > -1 {
                        // Create a duplicate with Num="-1"
                        let modifiedTag = fullTag.replacingOccurrences(of: #"Num="\#(num)""#, with: #"Num="-1""#)
                        print("Original: ", line, "Modified: ", modifiedTag)
                        modifiedLines.append(modifiedTag)

                        // Update progress
                        processedCount += 1
                        progressCallback(processedCount)
                    }
                }
            }
        }

        // Write the updated lines back to the file
        do {
            let updatedContents = modifiedLines.joined(separator: "\n")
            try updatedContents.write(to: file.url, atomically: true, encoding: .utf8)
            print("Memory cues successfully converted to hot cues.")
        } catch {
            print("Failed to write updated contents: \(error)")
        }
    }

    // Navigate to a directory
//    private func navigateToDirectory(_ path: URL) {
//        currentPath = path
//        loadContents(of: path)
//    }

    // Load directory contents
//    private func loadContents(of path: URL) {
//        do {
//            let fileURLs = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isDirectoryKey], options: [])
//            contents = fileURLs.compactMap { url in
//                var isDirectory: ObjCBool = false
//                FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
//                return FileItem(url: url, isDirectory: isDirectory.boolValue)
//            }
//        } catch {
//            print("Failed to load contents: \(error)")
//        }
//    }
}

// func loadChildren(of path: URL) -> [FileItem] {
//    do {
//        let fileURLs = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isDirectoryKey], options: [])
//        return fileURLs.compactMap { url in
//            var isDirectory: ObjCBool = false
//            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
//            if isDirectory.boolValue == false {
//                if isXMLFile(file: FileItem(url: url, isDirectory: isDirectory.boolValue)) {
//                    return FileItem(url: url, isDirectory: isDirectory.boolValue)
//                } else {
//                    return nil
//                }
//            } else {
//                return FileItem(url: url, isDirectory: isDirectory.boolValue, children: loadChildren(of: url))
//            }
//        }
//    } catch {
//        print("Failed to load contents: \(error)")
//        return []
//    }
// }
//
// func isXMLFile(file: FileItem) -> Bool {
//    return file.name.hasSuffix(".xml")
// }

struct ContentView: View {
    var body: some View {
        VStack {
            FileSystemView()
        }
    }
}

#Preview {
    ContentView()
}
