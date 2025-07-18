//
//  HelperViews.swift
//  MetaScribeKit
//
//  This file contains reusable SwiftUI views for the application.
//

import SwiftUI
import PDFKit

/// A view for displaying a PDF document.
public struct PDFKitView: NSViewRepresentable {
    public let url: URL
    
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


/// A custom picker view that allows for adding new entries to both the
/// main list and the sub-list.
public struct EditablePicker: View {
    // MARK: - Properties
    public let title: String
    @Binding public var selection: String?
    @Binding public var subSelection: String?
    @Binding public var list: [String]
    public let onAdd: (String) -> Void
    
    // State for the two different "Add New" sheets
    @State private var showingAddParentSheet = false
    @State private var showingAddChildSheet = false
    @State private var newParentEntry = ""
    @State private var newChildEntry = ""
    
    // MARK: - Initializer
    public init(title: String, selection: Binding<String?>, subSelection: Binding<String?>, list: Binding<[String]>, onAdd: @escaping (String) -> Void) {
        self.title = title
        self._selection = selection
        self._subSelection = subSelection
        self._list = list
        self.onAdd = onAdd
    }
    
    // MARK: - Computed Properties
    private var mainCategories: [String] {
        // Extracts the unique parent categories (e.g., "Finance") from the list.
        list.map { $0.components(separatedBy: "*").first ?? "" }.removingDuplicates().sorted()
    }
    
    private var subCategories: [String] {
        // Gets all child items for the currently selected parent.
        subcategories(for: selection ?? "", in: list)
    }
    
    // MARK: - Body
    public var body: some View {
        // --- Parent Picker ---
        Picker("\(title):", selection: Binding(get: { selection ?? "" }, set: { selection = $0 })) {
            ForEach(mainCategories, id: \.self) { cat in
                Text(cat).tag(cat)
            }
            Divider()
            Text("Add New...").tag("addNewParent")
        }
        .onChange(of: selection) { oldValue, newValue in
            if newValue == "addNewParent" {
                // If user selects "Add New...", show the sheet and revert the selection.
                showingAddParentSheet = true
                DispatchQueue.main.async {
                    self.selection = oldValue
                }
            } else {
                // When the parent changes, update the child selection to the first available item.
                self.subSelection = subcategories(for: newValue ?? "", in: list).first ?? ""
            }
        }
        
        // --- Sub-item Picker (The new, improved version) ---
        Picker("Sub\(title):", selection: Binding(get: { subSelection ?? "" }, set: { subSelection = $0 })) {
            // Add a "None" option to allow for optional sub-items.
            Text("None").tag("")
            
            ForEach(subCategories, id: \.self) { subcat in
                Text(subcat).tag(subcat)
            }
            
            // Only show the "Add New..." option if a parent category is selected.
            if !(selection ?? "").isEmpty {
                Divider()
                Text("Add New...").tag("addNewChild")
            }
        }
        .onChange(of: subSelection) { oldValue, newValue in
            if newValue == "addNewChild" {
                showingAddChildSheet = true
                DispatchQueue.main.async {
                    self.subSelection = oldValue
                }
            }
        }
        // Sheet for adding a new PARENT item (e.g., "Finance*Banking")
        .sheet(isPresented: $showingAddParentSheet) {
            addParentView()
        }
        // Sheet for adding a new CHILD item (e.g., just "Taxes" to "Finance")
        .sheet(isPresented: $showingAddChildSheet) {
            addChildView()
        }
    }
    
    // MARK: - Helper Views for Sheets
    
    /// The view for adding a new top-level entry.
    private func addParentView() -> some View {
        VStack {
            Text("Add New \(title)").font(.headline)
            Text("Use the format: Category*Subcategory").font(.subheadline).padding(.bottom)
            TextField("Example: Household*Gardening", text: $newParentEntry)
            HStack {
                Button("Cancel") { showingAddParentSheet = false }
                Spacer()
                Button("Save") {
                    onAdd(newParentEntry)
                    let parts = newParentEntry.components(separatedBy: "*")
                    if parts.count == 2 {
                        self.selection = parts[0]
                        self.subSelection = parts[1]
                    }
                    showingAddParentSheet = false
                }
                .disabled(newParentEntry.isEmpty || !newParentEntry.contains("*"))
            }
        }.padding().frame(width: 300)
    }
    
    /// The view for adding a new sub-item to the currently selected parent.
    private func addChildView() -> some View {
        VStack {
            Text("Add New Sub\(title) to '\(selection ?? "")'").font(.headline)
            TextField("New sub-item name", text: $newChildEntry)
            HStack {
                Button("Cancel") { showingAddChildSheet = false }
                Spacer()
                Button("Save") {
                    // Construct the full "Parent*Child" string and call the onAdd function.
                    let fullEntry = "\(selection ?? "")*\(newChildEntry)"
                    onAdd(fullEntry)
                    // Automatically select the newly added item.
                    self.subSelection = newChildEntry
                    showingAddChildSheet = false
                }
                .disabled(newChildEntry.isEmpty)
            }
        }.padding().frame(width: 300)
    }
}
