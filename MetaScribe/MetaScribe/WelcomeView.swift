//
//  WelcomeView.swift
//  MetaScribe
//
//  This is the view shown when the app is launched without any input.
//  It serves as the entry point for testing the core engine directly.
//

import SwiftUI

struct WelcomeView: View {
    // This view will get the shared AppState from the environment.
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            Text("MetaScribe").font(.largeTitle)
            Text("Ready for input.")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("This application is designed to be launched via a script or by dropping a file onto it.\n\nFor testing, you can select a document manually.")
                .multilineTextAlignment(.center)
                .padding()

            // This button triggers the file selection process.
            Button("Select Document to Process...") {
                selectAndProcessFile()
            }
        }
        .frame(minWidth: 500, minHeight: 300)
    }
    
    /// Shows a file picker and then updates the global AppState.
    private func selectAndProcessFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pdf, .jpeg, .png]

        if panel.runModal() == .OK {
            // If the user selects a file, get its URL.
            if let url = panel.url {
                // Update the shared AppState. This will cause the main
                // app view to switch over to the ContentView.
                appState.process(fileURL: url)
            }
        }
    }
}
