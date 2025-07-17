//
//  AppState.swift
//  MetaScribe
//
//  This is the Input Controller for the application. It's an ObservableObject
//  that holds the central state, such as the document being processed.
//  The rest of the app will watch this object for changes.
//

import SwiftUI

class AppState: ObservableObject {
    // MARK: - Published Properties
    // These properties will notify any listening views when they change.
    @Published var documentURL: URL?
    @Published var outputURL: URL?

    // MARK: - Public Methods
    
    /// Sets the state for processing a file from a direct URL (e.g., from a file picker).
    /// - Parameter url: The URL of the document to process.
    public func process(fileURL: URL) {
        // In this simple case, the output file is saved next to the original.
        self.outputURL = fileURL.deletingPathExtension().appendingPathExtension("json")
        // Setting this property will cause the main app view to switch to the ContentView.
        self.documentURL = fileURL
    }

    /// Handles an incoming URL from an external source like an AppleScript.
    /// It parses the URL to find the document and output paths.
    /// - Parameter incomingURL: The URL passed to the application on launch.
    public func handle(incomingURL: URL) {
        // Expected URL format: metascribe://process?docPath=/path/to/doc.pdf&outPath=/path/to/output.json
        guard let components = URLComponents(url: incomingURL, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            print("Error: Could not parse incoming URL.")
            return
        }

        // Find the 'docPath' and 'outPath' parameters.
        if let docPath = queryItems.first(where: { $0.name == "docPath" })?.value,
           let outPath = queryItems.first(where: { $0.name == "outPath" })?.value {
            
            // Update the state with the provided paths.
            // We must dispatch this to the main thread to ensure UI updates are smooth.
            DispatchQueue.main.async {
                self.outputURL = URL(fileURLWithPath: outPath)
                self.documentURL = URL(fileURLWithPath: docPath)
            }
        } else {
            print("Error: 'docPath' or 'outPath' missing from URL.")
        }
    }
}
