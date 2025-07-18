//
//  AppConfig.swift
//  MetaScribeKit
//

import SwiftUI
import Combine
import CryptoKit

public enum AppError: Error, LocalizedError {
    case initializationFailed(String)
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let message): return message }
    }
}

public class AppConfig: ObservableObject {
    public let appSupportURL: URL
    public let apiKey: String
    @Published public var promptTemplate: String
    @Published public var docTypes: [String]
    @Published public var categories: [String]
    public var initializationError: Error?

    public init() throws {
        guard let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw AppError.initializationFailed("Could not find the Application Support directory on this Mac.")
        }
        let appSupportURL = supportDir.appendingPathComponent("MetaScribeApp")
        try FileManager.default.createDirectory(at: appSupportURL, withIntermediateDirectories: true, attributes: nil)
        self.appSupportURL = appSupportURL

        func copyResource(filename: String) throws {
            let destinationURL = appSupportURL.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: destinationURL.path) {
                guard let sourceURL = Bundle.main.url(forResource: filename.components(separatedBy: ".").first, withExtension: filename.components(separatedBy: ".").last) else {
                    throw AppError.initializationFailed("Could not find '\(filename)' in the app's resources.")
                }
                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            }
        }

        try copyResource(filename: "api_key.txt")
        try copyResource(filename: "metascribe_prompt.txt")
        try copyResource(filename: "document_types.txt")
        try copyResource(filename: "categories.txt")

        func loadString(from filename: String) throws -> String {
            let fileURL = appSupportURL.appendingPathComponent(filename)
            do {
                return try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                throw AppError.initializationFailed("Could not load file: \(filename). Error: \(error.localizedDescription)")
            }
        }

        func loadList(from content: String) -> [String] {
            return content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        }

        self.apiKey = try loadString(from: "api_key.txt").trimmingCharacters(in: .whitespacesAndNewlines)
        self.promptTemplate = try loadString(from: "metascribe_prompt.txt")
        self.docTypes = loadList(from: try loadString(from: "document_types.txt"))
        self.categories = loadList(from: try loadString(from: "categories.txt"))
        self.initializationError = nil
    }

    public init(error: Error) {
        self.appSupportURL = URL(fileURLWithPath: "")
        self.apiKey = ""
        self.promptTemplate = ""
        self.docTypes = []
        self.categories = []
        self.initializationError = error
    }

    public func addCategory(newEntry: String) {
        guard !newEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.categories.append(newEntry)
        self.categories.sort()
        saveList(self.categories, to: "categories.txt")
    }

    public func addDocType(newEntry: String) {
        guard !newEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.docTypes.append(newEntry)
        self.docTypes.sort()
        saveList(self.docTypes, to: "document_types.txt")
    }

    public func savePromptTemplate(_ newPrompt: String) {
        self.promptTemplate = newPrompt
        let fileURL = appSupportURL.appendingPathComponent("metascribe_prompt.txt")
        do {
            try newPrompt.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("Error saving prompt template: \(error.localizedDescription)")
        }
    }

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
