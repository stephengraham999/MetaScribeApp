//
//  AIService.swift
//  MetaScribeKit
//
//  This module is responsible for all communication with the
//  Google Gemini multimodal AI. It is marked 'public' so the main
//  app can call it.
//

import Foundation
import SwiftUI // Needed for NSImage

/// Calls the Gemini Multimodal API with an image and a complex prompt.
/// - Parameters:
///   - apiKey: Your Google AI API key.
///   - image: The NSImage of the document to analyze.
///   - examples: A string containing few-shot learning examples.
///   - promptTemplate: The master prompt template string.
///   - docTypes: The list of document types to inject into the prompt.
///   - categories: The list of categories to inject into the prompt.
///   - fallbackDate: The file's creation date, to be used if no date is found in the text.
///   - completion: A closure that returns the raw JSON string response from the AI.
public func callMultimodalGeminiAPI(apiKey: String, image: NSImage, examples: String, promptTemplate: String, docTypes: [String], categories: [String], fallbackDate: String, completion: @escaping (String) -> Void) {
    
    // 1. Construct the final prompt by injecting the lists and examples
    var finalPrompt = promptTemplate
    let docTypesString = docTypes.joined(separator: "\n")
    let categoriesString = categories.joined(separator: "\n")
    
    finalPrompt = finalPrompt.replacingOccurrences(of: "{{DOCUMENT_TYPES_LIST}}", with: docTypesString)
    finalPrompt = finalPrompt.replacingOccurrences(of: "{{CATEGORIES_LIST}}", with: categoriesString)
    finalPrompt = finalPrompt.replacingOccurrences(of: "{{CORRECTION_EXAMPLES}}", with: examples)
    finalPrompt = finalPrompt.replacingOccurrences(of: "{{FILE_CREATION_DATE}}", with: fallbackDate)
    
    // 2. Prepare the image data by converting it to a Base64 encoded string
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]),
          !jpegData.isEmpty else {
        completion("Error: Could not convert image to JPEG data.")
        return
    }
    let base64Image = jpegData.base64EncodedString()
    
    // The AI prompt doesn't need the document text when it can see the image, so we remove the placeholder.
    let textPart = finalPrompt.replacingOccurrences(of: "{{DOCUMENT_TEXT}}", with: "")

    // 3. Construct the JSON request body for a multimodal request
    let jsonBody: [String: Any] = [
        "contents": [
            [
                "parts": [
                    ["text": textPart],
                    [
                        "inline_data": [
                            "mime_type": "image/jpeg",
                            "data": base64Image
                        ]
                    ]
                ]
            ]
        ]
    ]

    guard let httpBody = try? JSONSerialization.data(withJSONObject: jsonBody) else {
        completion("Error: Could not serialize JSON body.")
        return
    }
    
    // 4. Configure the network request
    let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=\(apiKey)")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = httpBody
    
    // 5. Execute the request and handle the response
    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data, error == nil else {
            completion("Network Error: \(error?.localizedDescription ?? "Unknown error")")
            return
        }
        if let jsonString = String(data: data, encoding: .utf8) {
            completion(jsonString)
        } else {
            completion("Error: Could not decode response.")
        }
    }.resume()
}
