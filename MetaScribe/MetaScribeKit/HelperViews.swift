//
//  HelperViews.swift
//  MetaScribeKit
//

import SwiftUI
import PDFKit

public struct PDFKitView: NSViewRepresentable {
    public let url: URL
    
    // ADDED: Public initializer
    public init(url: URL) {
        self.url = url
    }
    
    public func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: self.url)
        pdfView.autoScales = true
        return pdfView
    }
    
    public func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = PDFDocument(url: self.url)
    }
}

public struct EditablePicker: View {
    public let title: String
    @Binding public var selection: String?
    @Binding public var subSelection: String?
    @Binding public var list: [String]
    public let onAdd: (String) -> Void
    
    @State private var showingAddSheet = false
    @State private var newEntry = ""
    
    // ADDED: Public initializer
    public init(title: String, selection: Binding<String?>, subSelection: Binding<String?>, list: Binding<[String]>, onAdd: @escaping (String) -> Void) {
        self.title = title
        self._selection = selection
        self._subSelection = subSelection
        self._list = list
        self.onAdd = onAdd
    }
    
    private var mainCategories: [String] {
        list.map { $0.components(separatedBy: "*").first ?? "" }.removingDuplicates().sorted()
    }
    
    private var subCategories: [String] {
        subcategories(for: selection ?? "", in: list)
    }
    
    public var body: some View {
        Picker("\(title):", selection: Binding(get: { selection ?? "" }, set: { selection = $0 })) {
            ForEach(mainCategories, id: \.self) { cat in
                Text(cat).tag(cat)
            }
            Divider()
            Text("Add New...").tag("addNew")
        }
        .onChange(of: selection) { oldValue, newValue in
            if newValue == "addNew" {
                showingAddSheet = true
                DispatchQueue.main.async {
                    self.selection = oldValue
                }
            } else {
                self.subSelection = subcategories(for: newValue ?? "", in: list).first ?? ""
            }
        }
        
        Picker("Sub\(title):", selection: Binding(get: { subSelection ?? "" }, set: { subSelection = $0 })) {
            ForEach(subCategories, id: \.self) { subcat in
                Text(subcat).tag(subcat)
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            VStack {
                Text("Add New Entry").font(.headline)
                Text("Use the format: Category*Subcategory").font(.subheadline)
                TextField("Example: Household*Gardening", text: $newEntry)
                HStack {
                    Button("Cancel") { showingAddSheet = false }
                    Spacer()
                    Button("Save") {
                        onAdd(newEntry)
                        let parts = newEntry.components(separatedBy: "*")
                        if parts.count == 2 {
                            self.selection = parts[0]
                            self.subSelection = parts[1]
                        }
                        showingAddSheet = false
                    }
                }
            }.padding().frame(width: 300)
        }
    }
}
