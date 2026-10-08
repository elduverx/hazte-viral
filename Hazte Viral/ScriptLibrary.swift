//
//  ScriptLibrary.swift
//  goviiral
//

import Foundation
import Combine

/// Guiones generados, guardados en disco para que no se pierdan al cambiar de pestaña o cerrar la app.
@MainActor
final class ScriptLibrary: ObservableObject {
    static let shared = ScriptLibrary()

    @Published private(set) var scripts: [UGCScript] = []

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = fileURL ?? directory.appendingPathComponent("ugc_scripts.json")
        load()
    }

    func add(_ newScripts: [UGCScript]) {
        scripts.insert(contentsOf: newScripts, at: 0)
        save()
    }

    func delete(_ script: UGCScript) {
        scripts.removeAll { $0.id == script.id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            scripts = try JSONDecoder().decode([UGCScript].self, from: data)
        } catch {
            print("[ScriptLibrary] No se pudo leer el historial: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(scripts)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[ScriptLibrary] No se pudo guardar el historial: \(error)")
        }
    }
}

/// Cuota gratuita del Script Maker: cuenta generaciones (no guiones) y se reinicia cada mes.
@MainActor
final class ScriptQuota: ObservableObject {
    static let shared = ScriptQuota()
    static let freeMonthlyGenerations = 3

    @Published private(set) var usedThisMonth = 0

    private let defaults: UserDefaults
    private let usageKey = "ugc_monthly_generations"
    private let monthKey = "ugc_generations_month"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        resetIfNewMonth()
        usedThisMonth = defaults.integer(forKey: usageKey)
    }

    var remaining: Int {
        max(0, Self.freeMonthlyGenerations - usedThisMonth)
    }

    func canGenerate(isSubscribed: Bool) -> Bool {
        resetIfNewMonth()
        return isSubscribed || remaining > 0
    }

    func recordGeneration(isSubscribed: Bool) {
        guard !isSubscribed else { return }
        usedThisMonth += 1
        defaults.set(usedThisMonth, forKey: usageKey)
    }

    private func resetIfNewMonth() {
        let components = Calendar.current.dateComponents([.year, .month], from: Date())
        let currentMonth = (components.year ?? 0) * 100 + (components.month ?? 0)
        guard defaults.integer(forKey: monthKey) != currentMonth else { return }
        defaults.set(currentMonth, forKey: monthKey)
        defaults.set(0, forKey: usageKey)
        usedThisMonth = 0
    }
}
