//
//  MetaScribeApp.swift
//  MetaScribe
//
//  This is the main entry point for the application. It now includes
//  a menu command to open the prompt editor.
//

import SwiftUI
import MetaScribeKit

@main
struct MetaScribeApp: App {
    // Create a single instance of our AppState controller for the entire app.
    @StateObject private var appState = AppState()
    
    // We need an instance of AppConfig here to pass to the editor sheet.
    // This is the same config object used by ContentView.
    @StateObject private var config: AppConfig = {
        do {
            return try AppConfig()
        } catch {
            // In a real app, you might want more robust error handling here.
            // For now, we create a dummy object to prevent a crash.
            return AppConfig(error: error)
        }
    }()
    
    // State to control the visibility of the prompt editor window.
    @State private var showingPromptEditor = false

    var body: some Scene {
        WindowGroup {
            // The main view logic is unchanged.
            Group {
                if appState.documentURL != nil {
                    ContentView()
                } else {
                    WelcomeView()
                }
            }
            .environmentObject(appState)
            .onOpenURL { url in
                appState.handle(incomingURL: url)
            }
            // Present the PromptEditorView as a sheet when the state variable is true.
            .sheet(isPresented: $showingPromptEditor) {
                PromptEditorView(config: config)
            }
        }
        // This adds the new command to the application's menu bar.
        .commands {
            CommandMenu("Options") {
                Button("Edit AI Prompt...") {
                    showingPromptEditor = true
                }
                .keyboardShortcut("P", modifiers: [.command, .shift])
            }
        }
    }
}
