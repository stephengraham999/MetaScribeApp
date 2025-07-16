//
//  DataModels.swift
//  MetaScribeKit
//
//  This file defines the data structures used throughout the app.
//  They must be 'public' to be visible to the main MetaScribe app target.
//

import Foundation

// --- DATA MODELS ---

/// The primary structure for holding all extracted metadata.
/// Every property, and the initializer, must be public.
public struct ExtractedData: Codable, Hashable {
    public var date: String?
    public var contact: String?
    public var description: String?
    public var document_type: String?
    public var document_subtype: String?
    public var category: String?
    public var subcategory: String?
    
    // A public, empty initializer is required so other modules can create it.
    public init() {}
}

/// A structure for logging user corrections.
/// The struct, its properties, and its initializer must all be public.
public struct CorrectionLogEntry: Codable {
    public let originalImageHash: String
    public let correctedData: ExtractedData
    
    // A public initializer is required so other modules can create it.
    public init(originalImageHash: String, correctedData: ExtractedData) {
        self.originalImageHash = originalImageHash
        self.correctedData = correctedData
    }
}

// --- Structs for decoding the full Gemini response ---
// These can remain internal to the kit as they are only used when parsing.
struct GeminiResponse: Codable {
    let candidates: [Candidate]
}
struct Candidate: Codable {
    let content: Content
}
struct Content: Codable {
    let parts: [Part]
}
struct Part: Codable {
    let text: String
}
