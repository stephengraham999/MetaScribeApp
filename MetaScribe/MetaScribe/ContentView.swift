//
//  ContentView.swift
//  MetaScribe
//

import SwiftUI
import MetaScribeKit

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var config: AppConfig = {
        do {
            return try AppConfig()
        } catch {
            return AppConfig(error: error)
        }
    }()
    
    @State private var processingStatus: String = "Loading..."
    @State private var isProcessing: Bool = false
    @State private var editedData = ExtractedData()

    var body: some View {
        if let initError = config.initializationError {
            errorView(message: initError.localizedDescription)
        } else {
            mainProcessingView()
                .onAppear {
                    if let url = appState.documentURL {
                        startProcessing(fileURL: url)
                    }
                }
        }
    }
    
    private func errorView(message: String) -> some View {
        VStack(alignment: .leading) {
            Text("Fatal Error").font(.title).padding()
            Text("Could not initialize application configuration.").padding(.horizontal).padding(.bottom)
            Text("Error Details: \(message)")
                .font(.system(.body, design: .monospaced)).padding().background(Color(.textBackgroundColor)).cornerRadius(8).padding(.horizontal)
        }.frame(minWidth: 600, minHeight: 400)
    }
    
    private func mainProcessingView() -> some View {
        HSplitView {
            Group {
                if let docURL = appState.documentURL {
                    PDFKitView(url: docURL)
                } else {
                    VStack { Text(processingStatus); if isProcessing { ProgressView() } }
                }
            }
            .frame(minWidth: 450)

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
                .disabled(isProcessing)
                
                Spacer()
                
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
    
    private func startProcessing(fileURL: URL) {
        self.isProcessing = true
        self.processingStatus = "Processing: \(fileURL.lastPathComponent)..."
        
        processFile(url: fileURL) { result in
            switch result {
            case .success(let image):
                let fileCreationDate = getFileCreationDate(for: fileURL)
                
                // The 'examples' parameter is now an empty string.
                callMultimodalGeminiAPI(apiKey: config.apiKey, image: image, examples: "", promptTemplate: config.promptTemplate, docTypes: config.docTypes, categories: config.categories, fallbackDate: fileCreationDate) { responseString in
                    DispatchQueue.main.async {
                        if let data = parseAIResponse(responseString) {
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
    
    private func confirmAndSave() {
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
