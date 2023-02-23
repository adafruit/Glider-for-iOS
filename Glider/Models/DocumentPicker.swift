//
//  DocumentPicker.swift
//  Glider
//
//  Created by Antonio García on 8/2/23.
//

import SwiftUI

struct DocumentPicker: UIViewControllerRepresentable {
    
    let onUploadFile: ((_ fileName: String, _ data: Data)->Void)

    func makeCoordinator() -> DocumentPicker.Coordinator {
        return DocumentPicker.Coordinator(picker: self)
    }
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<DocumentPicker>) -> UIDocumentPickerViewController {
       // let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.text,.pdf])
              
        let picker = UIDocumentPickerViewController(documentTypes: ["public.item"], in: .import)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        picker.modalPresentationStyle = .fullScreen
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: DocumentPicker.UIViewControllerType, context: UIViewControllerRepresentableContext<DocumentPicker>) {
    }
    
    internal class Coordinator: NSObject, UIDocumentPickerDelegate {
        var picker: DocumentPicker
        
        init(picker: DocumentPicker){
            self.picker = picker
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard controller.documentPickerMode == .import, let url = urls.first else { return }
            
            let isScopedAccessUsed = url.startAccessingSecurityScopedResource()
            defer {
                if isScopedAccessUsed {
                    DispatchQueue.main.async {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
            
            DLog("selected: \(url.absoluteString)")
            
            do {
                let filename = url.lastPathComponent
                let data = try Data(contentsOf: url.absoluteURL)
                
                picker.onUploadFile(filename, data)
                
            }catch{
                DLog("Error: file contents could not be loaded")
            }
            //controller.dismiss(animated: true)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            DLog("dismiss")
        }
    }
}
