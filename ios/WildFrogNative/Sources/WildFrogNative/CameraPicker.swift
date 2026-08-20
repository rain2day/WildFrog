#if canImport(UIKit)
import SwiftUI
import UIKit

/// UIViewControllerRepresentable wrapping UIImagePickerController for camera capture.
struct CameraPicker: UIViewControllerRepresentable {
    @Binding var capturedImage: UIImage?
    var onCapture: ((UIImage) -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(capturedImage: Binding<UIImage?>, onCapture: ((UIImage) -> Void)? = nil) {
        _capturedImage = capturedImage
        self.onCapture = onCapture
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: CameraPicker

        init(_ parent: CameraPicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.capturedImage = image
                parent.onCapture?(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
#endif
