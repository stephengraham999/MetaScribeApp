//
//  ContentView.swift
//  MetaScribe
//
//  This is the main view of the application. For testing, it has been
//  modified to directly trigger the processing pipeline via a file picker,
//  allowing the core engine to be tested in isolation.
//

import SwiftUI
import MetaScribeKit // This line makes all our other modules visible

struct ContentView: View {
    // MARK: - App Configuration
    // The @StateObject property wrapper ensures that the AppConfig object, which
    // loads our API key and categories, is created once and shared.
    @StateObject private var config: AppConfig = {
        do {
            return try AppConfig()
        } catch {
            // If initialization fails, we create a version with the error stored.
            return AppConfig(error: error)
        }
    }()
    
    // MARK: - UI State Variables
    // These variables control the visibility and state of UI elements.
    
    // The text displayed to the user (e.g., "Ready", "Processing...", "Error...").
    @State private var processingStatus: String = "Ready. Select a document to begin."
    // A boolean to show/hide the progress indicator.
    @State private var isProcessing: Bool = false
    // The URL of the document being processed. When this is set, the UI will change.
    @State private var documentURL: URL?
    // The URL where the final JSON output will be saved.
    @State private var outputURL: URL?
    // Stores the initial data returned by the AI. Used to check if the user made changes.
    @State private var originalData = ExtractedData()
    // Stores the user-editable data. This is bound to the form fields.
    @State private var editedData = ExtractedData()

    // MARK: - Main View
    var body: some View {
        // First, check if there was a fatal error during app configuration.
        if let initError = config.initializationError {
            // If so, display an error view and stop.
            VStack(alignment: .leading) {
                Text("Fatal Error").font(.title).padding()
                Text("Could not initialize application configuration.").padding(.horizontal).padding(.bottom)
                Text("Error Details: \(initError.localizedDescription)")
                    .font(.system(.body, design: .monospaced)).padding().background(Color(.textBackgroundColor)).cornerRadius(8).padding(.horizontal)
            }.frame(minWidth: 600, minHeight: 400)
        } else {
            // If config is fine, check if a document is being processed.
            if documentURL == nil {
                // If no document is loaded, show the initial "debug" view.
                // This allows us to test the engine without an external script.
                testHarnessView()
            } else {
                // If a document URL is set, show the main processing view.
                mainProcessingView()
            }
        }
    }
    
    // MARK: - Subviews
    
    /// The view shown on launch, allowing us to select a file for testing.
    private func testHarnessView() -> some View {
        VStack(spacing: 20) {
            Text("MetaScribe Test Mode").font(.title)
            Text(processingStatus).padding()
            
            // This button triggers the file selection process.
            Button("Select Document to Process...") {
                selectAndProcessFile()
            }
            
            if isProcessing {
                ProgressView()
            }
        }.frame(minWidth: 800, minHeight: 600)
    }
    
    /// The main two-pane view for document review and editing.
    private func mainProcessingView() -> some View {
        HSplitView {
            // Left Pane: Document Preview
            Group {
                if let docURL = documentURL {
                    // We use the PDFKitView helper to display the document.
                    PDFKitView(url: docURL)
                }
            }
            .frame(minWidth: 450)

            // Right Pane: The Editable Form
            VStack {
                Form {
                    // Each section binds to a field in the 'editedData' object.
                    Section(header: Text("Details")) {
                        TextField("Contact", text: Binding(get: { editedData.contact ?? "" }, set: { editedData.contact = $0 }))
                        DatePicker("Date", selection: Binding(get: { dateFromString(editedData.date ?? "") }, set: { editedData.date = stringFromDate($0) }), displayedComponents: .date)
                        TextField("Description", text: Binding(get: { editedData.description ?? "" }, set: { editedData.description = $0 }))
                    }
                    Section(header: Text("Classification")) {
                        // The custom picker allows adding new categories on the fly.
                        EditablePicker(title: "Category", selection: $editedData.category, subSelection: $editedData.subcategory, list: $config.categories, onAdd: config.addCategory)
                    }
                    Section(header: Text("Document Type")) {
                        EditablePicker(title: "Type", selection: $editedData.document_type, subSelection: $editedData.document_subtype, list: $config.docTypes, onAdd: config.addDocType)
                    }
                }
                .padding()
                Spacer()
                
                // The final confirmation button.
                Button("Confirm & Save") {
                    confirmAndSave()
                }
                .padding()
                .disabled(documentURL == nil)
            }
            .frame(minWidth: 350)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // MARK: - Core Logic
    
    /// Shows a file picker and then starts the processing pipeline.
    private func selectAndProcessFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.pdf, .jpeg, .png] // Allow common document/image types

        if panel.runModal() == .OK {
            // If the user selects a file, get its URL.
            guard let url = panel.url else { return }
            
            // We'll set the output path to be the same directory as the input,
            // but with a .json extension.
            self.outputURL = url.deletingPathExtension().appendingPathExtension("json")
            
            // This is the entry point to the core engine.
            startProcessing(fileURL: url)
        }
    }
    
    /// This is the CORE PROCESSING ENGINE. It takes a file URL and performs all steps.
    /// This function is now completely separate from how the app was launched.
    private func startProcessing(fileURL: URL) {
        // 1. Update the UI to show we are busy.
        self.isProcessing = true
        self.processingStatus = "Processing: \(fileURL.lastPathComponent)..."
        self.documentURL = fileURL // Setting this switches the view to the main HSplitView
        
        // 2. Process the file (PDF or image) into a standard image format for the AI.
        processFile(url: fileURL) { result in
            switch result {
            case .success(let image):
                // 3. Find past corrections to improve the AI's accuracy.
                let correctionExamples = config.findCorrectionExamples(for: image)
                // Get the file's creation date as a fallback.
                let fileCreationDate = getFileCreationDate(for: fileURL)
                
                // 4. Call the AI service with the image and all required prompt data.
                callMultimodalGeminiAPI(apiKey: config.apiKey, image: image, examples: correctionExamples, promptTemplate: config.promptTemplate, docTypes: config.docTypes, categories: config.categories, fallbackDate: fileCreationDate) { responseString in
                    // This completion block runs when the AI responds.
                    // We must switch back to the main thread to update the UI.
                    DispatchQueue.main.async {
                        // 5. Parse the AI's JSON response into our data struct.
                        if let data = parseAIResponse(responseString) {
                            self.originalData = data
                            self.editedData = data
                        } else {
                            self.processingStatus = "Error: Could not parse AI response."
                        }
                        // 6. Mark processing as complete.
                        self.isProcessing = false
                    }
                }
            case .failure(let error):
                // If file processing fails, show an error.
                DispatchQueue.main.async {
                    self.processingStatus = "Error: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    /// Saves the final data and terminates the application.
    private func confirmAndSave() {
        // If the user edited the AI's suggestions, log the correction for future use.
        if originalData != editedData {
            if let docURL = documentURL, let image = NSImage(contentsOf: docURL) {
                config.logCorrection(for: image, correctedData: editedData)
            }
        }
        
        // Ensure the output path is set.
        guard let outputURL = self.outputURL else {
            print("Error: Output path is not set.")
            NSApplication.shared.terminate(self)
            return
        }

        // 1. Encode the final, user-approved data into JSON.
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(editedData)
            // 2. Write the JSON to the output file.
            try jsonData.write(to: outputURL)
            // 3. Quit the application.
            NSApplication.shared.terminate(self)
        } catch {
            print("Error saving JSON to output file: \(error)")
            NSApplication.shared.terminate(self)
        }
    }
}
