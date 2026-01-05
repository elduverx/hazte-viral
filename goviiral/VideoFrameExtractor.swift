import AVFoundation
import SwiftUI
import UniformTypeIdentifiers

class VideoFrameExtractor {
    static func extractFrames(from videoURL: URL, frameCount: Int = 3) async throws -> [CGImage] {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceAfter = .zero
        generator.requestedTimeToleranceBefore = .zero
        
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)
        
        guard durationInSeconds > 0 else {
            throw VideoAnalysisError.invalidVideo
        }
        
        var images: [CGImage] = []
        let timeStep = durationInSeconds / Double(frameCount + 1)
        
        for i in 1...frameCount {
            let time = CMTime(seconds: timeStep * Double(i), preferredTimescale: 600)
            
            do {
                let cgImage = try await generator.image(at: time).image
                images.append(cgImage)
            } catch {
                print("Failed to extract frame at time \(timeStep * Double(i)): \(error)")
                continue
            }
        }
        
        guard !images.isEmpty else {
            throw VideoAnalysisError.frameExtractionFailed
        }
        
        return images
    }
    
    static func imageToBase64(image: CGImage, quality: CGFloat = 0.8) -> String? {
        let data = CFDataCreateMutable(nil, 0)!
        guard let destination = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else {
            return nil
        }
        
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        
        CGImageDestinationAddImage(destination, image, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        
        let nsData = CFDataCreateCopy(nil, data) as Data
        return nsData.base64EncodedString()
    }
}

enum VideoAnalysisError: Error, LocalizedError {
    case invalidVideo
    case frameExtractionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidVideo:
            return "Invalid video file"
        case .frameExtractionFailed:
            return "Failed to extract frames from video"
        }
    }
}
