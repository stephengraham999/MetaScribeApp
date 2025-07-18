//
//  WelcomeView.swift
//  MetaScribe
//
//  This is the view shown when the app is launched without any input.
//  It now functions as a drop target and includes a manual file picker.
//

import SwiftUI
import UniformTypeIdentifiers // Required for UTType constants

struct WelcomeView: View {
    // This view gets the shared AppState from the environment.
    @EnvironmentObject var appState: AppState
    
    // State variables for showing an alert if the drop is invalid.
    @State private var showingAlert = false
    @State private var alertMessage = ""
    
    // State variable to change the view's appearance when dragging over it.
    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 80))
                .padding(.bottom)

            Text("MetaScribe").font(.largeTitle)
            
            Text("Drop a single document here to begin.")
                .font(.title2)
                .foregroundColor(.secondary)
            
            // Added a divider and an "or" to make the choice clear.
            HStack {
                VStack { Divider() }
                Text("or").padding(.horizontal)
                VStack { Divider() }
            }.padding()

            // The "Select Document" button is now back.
            Button("Select Document to Process...") {
                selectAndProcessFile()
            }

        }
        .frame(minWidth: 500, minHeight: 350)
        // This modifier makes the entire VStack a drop target.
        // We are specifying that it accepts items conforming to the .fileURL type.
        .onDrop(of: [UTType.fileURL], isTargeted: $isTargeted) { providers -> Bool in
            // When a drop occurs, this closure is executed.
            // We pass the item providers to our handler function.
            handleDrop(providers: providers)
            return true // Return true to indicate we've handled the drop.
        }
        // This changes the view's appearance when a file is being dragged over it.
        .background(isTargeted ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(20)
        // This presents an alert when the 'showingAlert' state variable is true.
        .alert(isPresented: $showingAlert) {
            Alert(title: Text("Invalid Drop"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    /// This function processes the items that were dropped onto the view.
    private func handleDrop(providers: [NSItemProvider]) {
        // We only care about the first item provider for our single-file design.
        guard let provider = providers.first else { return }
        
        // We ask the provider to load an object that conforms to the URL class.
        provider.loadObject(ofClass: URL.self) { url, error in
            // This completion handler runs once the item has been loaded.
            
            // First, ensure we are on the main thread before updating the UI or state.
            DispatchQueue.main.async {
                // Check that we have a valid URL and that only one item was dropped.
                guard let url = url, providers.count == 1 else {
                    self.alertMessage = "Please drop only a single file."
                    self.showingAlert = true
                    return
                }
                
                // Check if the URL points to a folder.
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    self.alertMessage = "Folders are not supported. Please drop a single document file."
                    self.showingAlert = true
                    return
                }
                
                // If all checks pass, we have a valid single file.
                // We update the shared AppState to begin processing.
                appState.process(fileURL: url)
            }
        }
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
