//
//  GlobalHelpers.swift
//  MetaScribeKit
//
//  This file contains global helper functions used across the application.
//  They are marked 'public' so the main app can access them.
//

import Foundation
import SwiftUI // Needed for NSImage and other UI elements
import PDFKit

/// Finds all subcategories that belong to a given main category from a list.
/// - Parameters:
///   - category: The main category to search for (e.g., "Finance").
///   - list: The array of strings in "Category*Subcategory" format.
/// - Returns: An array of matching subcategory strings, sorted alphabetically.
public func subcategories(for category: String, in list: [String]) -> [String] {
    return list.compactMap { line in
        let parts = line.components(separatedBy: "*")
        if parts.count == 2 && parts[0] == category {
            return parts[1]
        }
        return nil
    }.sorted()
}

/// An extension to the Array type to easily remove duplicate items.
public extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()
        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }
}

/// A shared, global date formatter to ensure consistency when converting dates.
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

/// Converts a "YYYY-MM-DD" string into a Date object.
/// - Parameter dateString: The date string to convert.
/// - Returns: A Date object, or today's date if the string is invalid.
public func dateFromString(_ dateString: String) -> Date {
    return dateFormatter.date(from: dateString) ?? Date()
}

/// Converts a Date object into a "YYYY-MM-DD" string.
/// - Parameter date: The Date object to convert.
/// - Returns: A formatted date string.
public func stringFromDate(_ date: Date) -> String {
    return dateFormatter.string(from: date)
}

/// Parses the full JSON string from the AI into our custom `ExtractedData` struct.
/// - Parameter jsonString: The raw JSON string returned by the Gemini API.
/// - Returns: An optional `ExtractedData` object if parsing is successful.
public func parseAIResponse(_ jsonString: String) -> ExtractedData? {
    guard let data = jsonString.data(using: .utf8) else { return nil }
    do {
        // First, decode the outer shell of the AI's response
        let outerResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        // Extract the inner text part, which contains our actual JSON data
        guard let textPart = outerResponse.candidates.first?.content.parts.first?.text else { return nil }
        
        // Clean up the inner JSON string, removing markdown formatting
        let cleanedText = textPart.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
        
        guard let innerData = cleanedText.data(using: .utf8) else { return nil }
        
        // Decode the cleaned inner JSON into our final data structure
        return try JSONDecoder().decode(ExtractedData.self, from: innerData)
    } catch {
        // Print detailed errors to the Xcode console for easier debugging
        print("JSON Parsing Error: \(error)")
        print("Original JSON String from AI: \(jsonString)")
        return nil
    }
}

/// Processes a file at a given URL into an NSImage.
/// It can handle both direct image files and the first page of a PDF.
/// - Parameters:
///   - url: The URL of the file to process.
///   - completion: A closure that returns either the resulting NSImage or an Error.
public func processFile(url: URL, completion: @escaping (Result<NSImage, Error>) -> Void) {
    // Try to open as a direct image first
    if let image = NSImage(contentsOf: url) {
        completion(.success(image))
        return
    }
    
    // If that fails, try to open as a PDF and render the first page
    if let pdf = PDFDocument(url: url), let page = pdf.page(at: 0) {
        let pdfRect = page.bounds(for: .mediaBox)
        let image = NSImage(size: pdfRect.size, flipped: false) { (rect) -> Bool in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            context.saveGState()
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()
            return true
        }
        completion(.success(image))
        return
    }
    
    // If both fail, return an error
    completion(.failure(NSError(domain: "FileError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not open file as PDF or Image."])))
}

/// Gets the creation date of a file from the file system.
/// - Parameter url: The URL of the file.
/// - Returns: A formatted "YYYY-MM-DD" string, or today's date as a fallback.
public func getFileCreationDate(for url: URL) -> String {
    do {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let creationDate = attributes[.creationDate] as? Date {
            return stringFromDate(creationDate)
        }
    } catch {
        print("Could not get file attributes: \(error)")
    }
    // Fallback to today's date if creation date can't be found
    return stringFromDate(Date())
}
