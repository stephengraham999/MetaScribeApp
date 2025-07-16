//
//  MetaScribeApp.swift
//  MetaScribe
//
//  This is the main entry point for the application. The @main attribute
//  tells the system that this is where the app starts.
//

import SwiftUI

@main
struct MetaScribeApp: App {
    var body: some Scene {
        // This creates the main window and places our ContentView inside it.
        // If the compiler can't find 'ContentView', it means there's a
        // problem with how that file is included in the app target.
        WindowGroup {
            ContentView()
        }
    }
}
