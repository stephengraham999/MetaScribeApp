//
//  MetaScribeApp.swift
//  MetaScribe
//
//  This is the main entry point for the application. It now manages the
//  app's state and listens for incoming URLs.
//

import SwiftUI

@main
struct MetaScribeApp: App {
    // Create a single instance of our AppState controller for the entire app.
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            // The view logic is now centralized here.
            Group {
                if appState.documentURL != nil {
                    ContentView()
                } else {
                    // Otherwise, show the default welcome/testing view.
                    WelcomeView()
                }
            }
            // Make the appState object available to all child views.
            .environmentObject(appState)
            // This modifier listens for the app being opened via a URL scheme.
            // It is now correctly attached to the View inside the WindowGroup.
            .onOpenURL { url in
                appState.handle(incomingURL: url)
            }
        }
    }
}
