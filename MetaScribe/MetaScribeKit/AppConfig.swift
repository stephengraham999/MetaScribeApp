//
//  AppConfig.swift
//  MetaScribeKit
//
//  This module handles loading, managing, and saving all user configuration
//  and learning data. It is marked 'public' so the main app can access it.
//

import SwiftUI
import Combine      // <-- This import is required for ObservableObject and @Published
import CryptoKit

/// Custom Error Type for readable initialization errors.
public enum AppError: Error, LocalizedError {
    case initializationFailed(String)
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message):
            return message
        }
    }
}

/// --- CONFIGURATION & FILE MANAGEMENT CLASS ---
/// This class is an ObservableObject, which means the main UI can watch it for changes.
public class AppConfig: ObservableObject {
    // MARK: - Properties
    public let appSupportURL: URL
    public let apiKey: String
    public var promptTemplate: String
    
    // These are marked @Published so that if they change (e.g., a new category is added),
    // the UI will automatically update to show the new item.
    @Published public var docTypes: [String]
    @Published public var categories: [String]
    
    public var corrections: [CorrectionLogEntry]
    public var initializationError: Error?

    // MARK: - Initializers
    
    /// The main failable initializer that sets up and loads everything.
    public init() throws {
        // 1. Find or create the Application Support directory for our app
        guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppError.initializationFailed("Could not find the Application Support directory on this Mac.")
        }
        let appSupportURL = supportDir.appendingPathComponent("MetaScribeApp")
        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        
        // 2. A helper function to copy default files from the app bundle if they don't exist
        func copyResource(filename: String) throws {
            let destinationURL = appSupportURL.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: destinationURL.path) {
                guard let sourceURL = Bundle.main.url(forResource: filename.components(separatedBy: ".").first, withExtension: filename.components(separatedBy: ".").last) else {
                    throw AppError.initializationFailed("Could not find '\(filename)' in the app's resources. Make sure it has been added to the Xcode project and is included in the MetaScribeKit target.")
                }
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            }
        }
        
        // 3. Copy all required configuration files
        try copyResource(filename: "api_key.txt")
        try copyResource(filename: "metascribe_prompt.txt")
        try copyResource(filename: "document_types.txt")
        try copyResource(filename: "categories.txt")
        
        // 4. A helper function to load a string from a file in the App Support folder
        func loadString(from filename: String) throws -> String {
            let fileURL = appSupportURL.appendingPathComponent(filename)
            do {
                return try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                throw AppError.initializationFailed("Could not load file: \(filename). It may be missing or corrupt. Error: \(error.localizedDescription)")
            }
        }
        
        // 5. Helper functions to parse the loaded strings
        func loadList(from content: String) -> [String] {
            return content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        }
        func loadCorrections(from content: String) -> [CorrectionLogEntry] {
            let lines = content.components(separatedBy: .newlines)
            return lines.compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? JSONDecoder().decode(CorrectionLogEntry.self, from: data)
            }
        }
        
        // 6. Load all data and initialize the class properties
        self.appSupportURL = appSupportURL
        self.apiKey = try loadString(from: "api_key.txt").trimmingCharacters(in: .whitespacesAndNewlines)
        self.promptTemplate = try loadString(from: "metascribe_prompt.txt")
        self.docTypes = loadList(from: try loadString(from: "document_types.txt"))
        self.categories = loadList(from: try loadString(from: "categories.txt"))
        self.corrections = loadCorrections(from: (try? loadString(from: "corrections.jsonl")) ?? "")
        self.initializationError = nil
    }
    
    /// A separate, non-failable initializer for creating a dummy object in case of an error.
    public init(error: Error) {
        self.appSupportURL = URL(fileURLWithPath: "")
        self.apiKey = ""
        self.promptTemplate = ""
        self.docTypes = []
        self.categories = []
        self.corrections = []
        self.initializationError = error
    }
    
    // MARK: - Public Methods
    
    /// Adds a new entry to the categories list and saves it to disk.
    public func addCategory(newEntry: String) {
        guard !newEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.categories.append(newEntry)
        self.categories.sort()
        saveList(self.categories, to: "categories.txt")
    }

    /// Adds a new entry to the document types list and saves it to disk.
    public func addDocType(newEntry: String) {
        guard !newEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.docTypes.append(newEntry)
        self.docTypes.sort()
        saveList(self.docTypes, to: "document_types.txt")
    }
    
    /// Saves a correction to the learning log.
    public func logCorrection(for image: NSImage, correctedData: ExtractedData) {
        let imageHash = image.tiffRepresentation?.md5 ?? ""
        let newEntry = CorrectionLogEntry(originalImageHash: imageHash, correctedData: correctedData)
        self.corrections.append(newEntry)
        
        let fileURL = appSupportURL.appendingPathComponent("corrections.jsonl")
        do {
            let jsonData = try JSONEncoder().encode(newEntry)
            if var jsonString = String(data: jsonData, encoding: .utf8) {
                jsonString += "\n" // Append newline for JSONL format
                if let fileHandle = try? FileHandle(forWritingTo: fileURL) {
                    defer { fileHandle.closeFile() }
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(jsonString.data(using: .utf8)!)
                } else {
                    // If the file doesn't exist, create it for the first time
                    try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
                }
            }
        } catch {
            print("Error logging correction: \(error.localizedDescription)")
        }
    }
    
    /// Finds relevant past corrections to use as examples in the AI prompt.
    public func findCorrectionExamples(for image: NSImage) -> String {
        // In a real app, this would use a more sophisticated similarity search.
        // For now, we'll just take the last 2 corrections as examples.
        let recentCorrections = corrections.suffix(2)
        let examples = recentCorrections.map { "Example Correction: \(String(describing: $0.correctedData))" }.joined(separator: "\n\n")
        return examples
    }
    
    // MARK: - Private Methods
    
    /// Saves a list of strings to a specified file in the App Support directory.
    private func saveList(_ list: [String], to filename: String) {
        let fileURL = appSupportURL.appendingPathComponent(filename)
        let content = list.joined(separator: "\n")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving list to \(filename): \(error.localizedDescription)")
        }
    }
}

/// A simple MD5 Hashing extension on Data for the learning loop.
public extension Data {
    var md5: String {
        let digest = Insecure.MD5.hash(data: self)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}
