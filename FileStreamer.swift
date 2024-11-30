//
//  FileStreamer.swift
//  RekordTool
//
//  Created by Piergiorgio Gonni on 2024-11-30.
//

import Foundation

class StreamReader {
    private let fileHandle: FileHandle
    private let buffer: NSMutableData
    private let delimiter: Data
    private let encoding: String.Encoding
    private var atEOF: Bool = false

    init?(url: URL, delimiter: String = ">", encoding: String.Encoding = .utf8) {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        self.fileHandle = fileHandle
        // Append line endings to the delimiter to support variations
        self.delimiter = delimiter.data(using: encoding)!
        self.buffer = NSMutableData()
        self.encoding = encoding
    }

    deinit {
        self.close()
    }

    func close() {
        fileHandle.closeFile()
    }

    func nextLine() -> String? {
        while !atEOF {
            // Find the range of the delimiter in the buffer
            let range = buffer.range(of: delimiter, options: [], in: NSRange(location: 0, length: buffer.length))

            if range.location != NSNotFound {
                // Extract the data within the range
                let lineData = buffer.subdata(with: NSRange(location: 0, length: range.location))

                // Convert the data to a string
                if let line = String(data: lineData, encoding: encoding) {
                    // Remove the processed data and the delimiter from the buffer
                    buffer.replaceBytes(in: NSRange(location: 0, length: range.upperBound), withBytes: nil, length: 0)
                    // Append the delimiter back to the line
                    return line + (String(data: delimiter, encoding: encoding) ?? "")
                } else {
                    print("Failed to decode line data: \(lineData)")
                    return nil
                }
            }

            // Read the next chunk into the buffer
            let chunk = fileHandle.readData(ofLength: 4096)
            if chunk.isEmpty {
                atEOF = true
                if buffer.length > 0 {
                    // Return the remaining data as the final line
                    if let line = String(data: buffer as Data, encoding: encoding) {
                        buffer.length = 0
                        return line
                    }
                }
                return nil
            }
            buffer.append(chunk)
        }
        return nil
    }
}
