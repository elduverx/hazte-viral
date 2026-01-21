//
//  AnalyzerViewModel.swift
//  goviiral
//
//  Created by OpenAI Assistant on 8/12/25.
//

import AVFoundation
import AVKit
import Combine
import Foundation
import PhotosUI
import SwiftUI

@MainActor
final class AnalyzerViewModel: ObservableObject {
    @Published var selectedVideoURL: URL?
    @Published var player: AVPlayer?
    @Published var report: AnalysisReport?
    @Published var isAnalyzing = false
    @Published var isLoadingVideo = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showHistory = false
    @Published var displayName = "Your video"
    @Published private(set) var history: [AnalysisReport] = []

    private let service: AIAnalysisProviding
    private let historyStore: HistoryStore

    init(service: AIAnalysisProviding? = nil, historyStore: HistoryStore = HistoryStore()) {
        print("[Init] Inicializando AnalyzerViewModel...")
        
        if let service = service {
            print("[Config] Usando servicio personalizado: \(type(of: service))")
            self.service = service
        } else {
            if let key = ClaudeConfig.apiKey, !key.isEmpty {
                print("[Config] Claude API key detectada: \(String(key.prefix(8)))...")
            } else {
                print("[Warn] ANTHROPIC_API_KEY no está configurada; la llamada real a Claude fallará hasta agregarla")
            }

            let claudeService = ClaudeAIService(apiKey: ClaudeConfig.apiKey)
            print("[Config] Servicio configurado: \(type(of: claudeService)) (sin mocks)")
            self.service = claudeService
        }
        
        self.historyStore = historyStore
        history = historyStore.reports
        print("[Init] ViewModel inicializado con \(history.count) reportes en historial")
    }

    func handleLegacySelection(with url: URL) {
        prepareForNewSelection()
        finalizeSelection(with: url, displayName: url.lastPathComponent)
    }

    @available(iOS 16.0, macOS 13.0, *)
    func loadVideo(from item: PhotosPickerItem) async {
        prepareForNewSelection()
        do {
            let data = try await item.loadTransferable(type: Data.self)
            guard let data = data else { throw AnalysisError.invalidVideo }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try data.write(to: tempURL)

            finalizeSelection(with: tempURL, displayName: item.itemIdentifier)
        } catch {
            present(error: error)
            isLoadingVideo = false
        }
    }

    func resetSelection() {
        stopCurrentPlayback()
        selectedVideoURL = nil
        report = nil
        isAnalyzing = false
        displayName = "Your video"
    }

    private func prepareForNewSelection() {
        stopCurrentPlayback()
        report = nil
        isAnalyzing = false
        isLoadingVideo = true
    }

    private func finalizeSelection(with url: URL, displayName name: String?) {
        selectedVideoURL = url
        player = AVPlayer(url: url)
        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        displayName = trimmedName?.isEmpty == false ? trimmedName! : "Video"
        isLoadingVideo = false
    }

    private func stopCurrentPlayback() {
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player = nil
    }

    func analyze() async {
        print("[Analysis] Iniciando análisis...")
        
        guard let videoURL = selectedVideoURL else {
            print("[Error] No hay video seleccionado")
            present(error: AnalysisError.invalidVideo)
            return
        }

        let hash = FileHasher.hash(of: videoURL)
        if let hash, let cached = history.first(where: { $0.videoHash == hash }) {
            print("[Cache] Reutilizando resultado previo para este video (hash coincidente)")
            report = cached
            return
        }

        print("[Analysis] Analizando video: \(videoURL.lastPathComponent)")
        print("[Config] Servicio utilizado: \(type(of: service))")
        
        isAnalyzing = true
        do {
            print("[Network] Llamando al servicio de análisis...")
            let result = try await service.analyze(videoURL: videoURL, title: displayName, videoHash: hash)
            print("[Analysis] Análisis completado exitosamente")
            
            report = result
            historyStore.add(result)
            history = historyStore.reports
            
            print("[Result] \(result.predictedViews) vistas predichas")
        } catch {
            print("[Error] Error durante análisis: \(error)")
            present(error: error)
        }
        isAnalyzing = false
        print("[Analysis] Análisis finalizado")
    }

    func present(error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        showError = true
    }
}
