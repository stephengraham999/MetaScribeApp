//
//  PromptEditorView.swift
//  MetaScribe
//
//  A view that allows the user to edit the main AI prompt template.
//

import SwiftUI
import MetaScribeKit

struct PromptEditorView: View {
    // The AppConfig object, passed from the parent view.
    @ObservedObject var config: AppConfig
    
    // A local state variable to hold the text being edited.
    @State private var promptText: String = ""
    
    // A way to programmatically close this view/window.
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        VStack {
            Text("Edit AI Prompt Template")
                .font(.title)
                .padding()

            // A scrolling text editor for the prompt.
            TextEditor(text: $promptText)
                .font(.system(.body, design: .monospaced))
                .padding(5)
                .border(Color.gray.opacity(0.5), width: 1)
                .padding()

            HStack {
                Button("Cancel") {
                    // Dismiss the view without saving.
                    presentationMode.wrappedValue.dismiss()
                }
                
                Spacer()
                
                Button("Save") {
                    // Call the save function in AppConfig and then dismiss.
                    config.savePromptTemplate(promptText)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction) // Allows hitting Enter to save.
            }
            .padding()
        }
        .frame(minWidth: 600, minHeight: 500)
        .onAppear {
            // When the view appears, load the current prompt into the editor.
            self.promptText = config.promptTemplate
        }
    }
}
