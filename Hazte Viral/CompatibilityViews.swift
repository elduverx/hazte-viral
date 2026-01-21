import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif
#if canImport(UniformTypeIdentifiers)
import UniformTypeIdentifiers
#endif

/// Wraps NavigationStack when available, otherwise falls back to NavigationView for older OS versions.
struct CompatibleNavigationStack<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationStack { content() }
        } else {
            NavigationView { content() }
        }
    }
}

#if os(iOS)
#if canImport(PhotosUI)
#if canImport(UniformTypeIdentifiers)
/// Legacy PHPicker replacement used on iOS 15 to obtain a local video URL.
struct LegacyVideoPicker: UIViewControllerRepresentable {
    typealias UIViewControllerType = PHPickerViewController

    var onSelection: (URL?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration(photoLibrary: .shared())
        configuration.filter = .videos
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: LegacyVideoPicker

        init(parent: LegacyVideoPicker) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
                DispatchQueue.main.async { self.parent.onSelection(nil) }
                return
            }

            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                guard let url = url, error == nil else {
                    DispatchQueue.main.async { self.parent.onSelection(nil) }
                    return
                }

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension.isEmpty ? "mov" : url.pathExtension)

                do {
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    DispatchQueue.main.async { self.parent.onSelection(tempURL) }
                } catch {
                    DispatchQueue.main.async { self.parent.onSelection(nil) }
                }
            }
        }
    }
}
#endif
#endif
#endif

extension View {
    @ViewBuilder
    func compatibleTint(_ color: Color) -> some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            self.tint(color)
        } else {
            self.accentColor(color)
        }
    }
}
