//
//  ContentView.swift
//  MetaScribe
//
//  This is the main view for processing a document. It now receives all
//  its state from the shared AppState environment object.
//

import SwiftUI
import MetaScribeKit // This line makes all our other modules visible

struct ContentView: View {
    // MARK: - Environment & State
    // The shared state that controls which document is being processed.
    @EnvironmentObject var appState: AppState
    
    // The configuration for API keys, categories, etc.
    @StateObject private var config: AppConfig = {
        do {
            return try AppConfig()
        } catch {
            return AppConfig(error: error)
        }
    }()
    
    // Local state for this view.
    @State private var processingStatus: String = "Loading..."
    @State private var isProcessing: Bool = false
    @State private var originalData = ExtractedData()
    @State private var editedData = ExtractedData()

    // MARK: - Main View
    var body: some View {
        // First, check if there was a fatal error during app configuration.
        if let initError = config.initializationError {
            errorView(message: initError.localizedDescription)
        } else {
            // If config is fine, show the main processing view.
            mainProcessingView()
                .onAppear {
                    // When this view appears, it means a documentURL has been set
                    // in the AppState, so we can start processing immediately.
                    if let url = appState.documentURL {
                        startProcessing(fileURL: url)
                    }
                }
        }
    }
    
    // MARK: - Subviews
    
    /// A generic view to display fatal errors.
    private func errorView(message: String) -> some View {
        VStack(alignment: .leading) {
            Text("Fatal Error").font(.title).padding()
            Text("Could not initialize application configuration.").padding(.horizontal).padding(.bottom)
            Text("Error Details: \(message)")
                .font(.system(.body, design: .monospaced)).padding().background(Color(.textBackgroundColor)).cornerRadius(8).padding(.horizontal)
        }.frame(minWidth: 600, minHeight: 400)
    }
    
    /// The main two-pane view for document review and editing.
    private func mainProcessingView() -> some View {
        HSplitView {
            // Left Pane: Document Preview
            Group {
                // The documentURL now comes directly from the AppState.
                if let docURL = appState.documentURL {
                    PDFKitView(url: docURL)
                } else {
                    // This is a fallback view in case the URL is somehow nil.
                    VStack {
                        Text(processingStatus)
                        if isProcessing { ProgressView() }
                    }
                }
            }
            .frame(minWidth: 450)

            // Right Pane: The Editable Form (This part is unchanged)
            VStack {
                Form {
                    Section(header: Text("Details")) {
                        TextField("Contact", text: Binding(get: { editedData.contact ?? "" }, set: { editedData.contact = $0 }))
                        DatePicker("Date", selection: Binding(get: { dateFromString(editedData.date ?? "") }, set: { editedData.date = stringFromDate($0) }), displayedComponents: .date)
                        TextField("Description", text: Binding(get: { editedData.description ?? "" }, set: { editedData.description = $0 }))
                    }
                    Section(header: Text("Classification")) {
                        EditablePicker(title: "Category", selection: $editedData.category, subSelection: $editedData.subcategory, list: $config.categories, onAdd: config.addCategory)
                    }
                    Section(header: Text("Document Type")) {
                        EditablePicker(title: "Type", selection: $editedData.document_type, subSelection: $editedData.document_subtype, list: $config.docTypes, onAdd: config.addDocType)
                    }
                }
                .padding()
                .disabled(isProcessing) // Disable form while processing
                
                Spacer()
                
                // The final confirmation button.
                Button("Confirm & Save") {
                    confirmAndSave()
                }
                .padding()
                .disabled(appState.documentURL == nil || isProcessing)
            }
            .frame(minWidth: 350)
        }
        .frame(minWidth: 800, minHeight: 600)
    }
    
    // MARK: - Core Logic
    
    /// This is the CORE PROCESSING ENGINE. It takes a file URL and performs all steps.
    private func startProcessing(fileURL: URL) {
        self.isProcessing = true
        self.processingStatus = "Processing: \(fileURL.lastPathComponent)..."
        
        processFile(url: fileURL) { result in
            switch result {
            case .success(let image):
                let correctionExamples = config.findCorrectionExamples(for: image)
                let fileCreationDate = getFileCreationDate(for: fileURL)
                
                callMultimodalGeminiAPI(apiKey: config.apiKey, image: image, examples: correctionExamples, promptTemplate: config.promptTemplate, docTypes: config.docTypes, categories: config.categories, fallbackDate: fileCreationDate) { responseString in
                    DispatchQueue.main.async {
                        if let data = parseAIResponse(responseString) {
                            self.originalData = data
                            self.editedData = data
                            self.processingStatus = "Reviewing: \(fileURL.lastPathComponent)"
                        } else {
                            self.processingStatus = "Error: Could not parse AI response."
                        }
                        self.isProcessing = false
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.processingStatus = "Error: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    /// Saves the final data and terminates the application.
    private func confirmAndSave() {
        if originalData != editedData {
            if let docURL = appState.documentURL, let image = NSImage(contentsOf: docURL) {
                config.logCorrection(for: image, correctedData: editedData)
            }
        }
        
        // The outputURL now comes from the shared AppState.
        guard let outputURL = appState.outputURL else {
            print("Error: Output path is not set in AppState.")
            NSApplication.shared.terminate(self)
            return
        }

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(editedData)
            try jsonData.write(to: outputURL)
            NSApplication.shared.terminate(self)
        } catch {
            print("Error saving JSON to output file: \(error)")
            NSApplication.shared.terminate(self)
        }
    }
}
