//
//  UGCScriptMakerView.swift
//  goviiral
//
//  Created by Claude on 8/12/25.
//

import SwiftUI

struct UGCScriptMakerView: View {
    @StateObject private var viewModel = UGCScriptViewModel()
    @ObservedObject private var library = ScriptLibrary.shared
    @ObservedObject private var quota = ScriptQuota.shared
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var scheme

    @State private var mode: Mode = .create
    @State private var selectedScript: UGCScript?
    @FocusState private var focusedField: Field?
    @State private var showAllNiches = false
    @State private var pendingAIAction: (() -> Void)?

    private let collapsedNicheCount = 8

    /// Los 8 nichos más comunes, más el elegido si está entre los ocultos.
    private var visibleNiches: [BusinessNiche] {
        guard !showAllNiches else { return BusinessNiche.allCases }
        var niches = Array(BusinessNiche.allCases.prefix(collapsedNicheCount))
        if let selected = BusinessNiche.named(viewModel.brief.nicheID), !niches.contains(where: { $0.id == selected.id }) {
            niches.append(selected)
        }
        return niches
    }

    enum Mode: String, CaseIterable {
        case create = "Crear"
        case library = "Mis guiones"
    }

    enum Field: Hashable {
        case customNiche, businessType, product, audience, benefit(Int)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()
                BackgroundGlow().opacity(0.6)

                VStack(spacing: 0) {
                    Picker("Modo", selection: $mode) {
                        ForEach(Mode.allCases, id: \.self) { mode in
                            Text(mode == .library && !library.scripts.isEmpty
                                 ? "\(mode.rawValue) (\(library.scripts.count))" : mode.rawValue)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)

                    switch mode {
                    case .create: createFlow
                    case .library: libraryList
                    }
                }

                if viewModel.isGenerating {
                    AIProcessingView(
                        title: viewModel.brief.count == 1 ? "Creando tu guion" : "Creando \(viewModel.brief.count) guiones",
                        stages: ScriptGenerationStage.allCases.map(\.title),
                        currentStage: viewModel.generationStage.rawValue,
                        onCancel: { viewModel.cancelGeneration() }
                    )
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isGenerating)
            .navigationTitle("Script Maker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ProStatusButton { viewModel.showPaywall = true }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") { focusedField = nil }
                }
            }
        }
        .sheet(item: $selectedScript) { UGCScriptDetailView(script: $0) }
        .sheet(isPresented: $viewModel.showPaywall) { SubscriptionPaywallView() }
        .aiConsentSheet(pendingAction: $pendingAIAction)
        .alert("No se pudo continuar", isPresented: errorBinding) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } })
    }

    // MARK: - Flujo de creación

    private var createFlow: some View {
        ScrollView {
            VStack(spacing: 20) {
                StepIndicator(current: viewModel.step)

                Group {
                    switch viewModel.step {
                    case .business: businessStep
                    case .style: styleStep
                    case .results: resultsStep
                    }
                }
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .opacity))
            }
            .padding()
            .animation(.snappy(duration: 0.3), value: viewModel.step)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    // Paso 1
    private var businessStep: some View {
        VStack(spacing: 16) {
            FormCard(title: "¿Cuál es tu nicho?") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    ForEach(visibleNiches) { niche in
                        SelectableChip(icon: niche.icon, title: niche.name,
                                       isSelected: viewModel.brief.nicheID == niche.id) {
                            viewModel.brief.nicheID = niche.id
                        }
                    }
                    SelectableChip(icon: "square.and.pencil", title: "Otro",
                                   isSelected: viewModel.brief.isCustomNiche) {
                        viewModel.brief.nicheID = BusinessNiche.otherID
                        focusedField = .customNiche
                    }
                }

                if BusinessNiche.allCases.count > collapsedNicheCount {
                    Button {
                        showAllNiches.toggle()
                    } label: {
                        Label(showAllNiches ? "Ver menos" : "Ver más nichos (\(BusinessNiche.allCases.count - collapsedNicheCount))",
                              systemImage: showAllNiches ? "chevron.up" : "chevron.down")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundStyle(Theme.accentStart)
                }

                if viewModel.brief.isCustomNiche {
                    InputField(title: "Escribe tu nicho", placeholder: "Tatuajes, coaching, gaming, apicultura…",
                               text: $viewModel.brief.customNiche)
                        .focused($focusedField, equals: .customNiche)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .businessType }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.snappy(duration: 0.25), value: viewModel.brief.isCustomNiche)
            .animation(.snappy(duration: 0.25), value: showAllNiches)

            FormCard(title: "Cuéntanos más") {
                VStack(spacing: 14) {
                    InputField(title: "Tipo de negocio", placeholder: "Restaurante italiano, clínica dental…",
                               text: $viewModel.brief.businessType)
                        .focused($focusedField, equals: .businessType)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .product }
                    InputField(title: "Producto o servicio", placeholder: "Pizza de masa madre, blanqueamiento…",
                               text: $viewModel.brief.productService)
                        .focused($focusedField, equals: .product)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .audience }
                    InputField(title: "Público objetivo", placeholder: "Familias jóvenes de 25-40 años…",
                               text: $viewModel.brief.targetAudience)
                        .focused($focusedField, equals: .audience)
                        .submitLabel(.next)
                        .onSubmit { focusedField = .benefit(0) }
                }
            }

            FormCard(title: "Beneficios clave", trailing: benefitsCounter) {
                VStack(spacing: 10) {
                    ForEach(viewModel.brief.benefits.indices, id: \.self) { index in
                        HStack(spacing: 10) {
                            InputField(title: nil, placeholder: "Ej. Entrega en 30 minutos",
                                       text: $viewModel.brief.benefits[index])
                                .focused($focusedField, equals: .benefit(index))
                            if viewModel.brief.benefits.count > 1 {
                                Button {
                                    viewModel.removeBenefit(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(Theme.secondary(scheme))
                                }
                                .accessibilityLabel("Quitar beneficio")
                            }
                        }
                    }
                    if viewModel.brief.benefits.count < ScriptBrief.maxBenefits {
                        Button {
                            viewModel.addBenefit()
                            focusedField = .benefit(viewModel.brief.benefits.count - 1)
                        } label: {
                            Label("Añadir beneficio", systemImage: "plus")
                                .font(.subheadline.weight(.medium))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .foregroundStyle(Theme.accentStart)
                    }
                }
            }
        }
    }

    private var benefitsCounter: Text {
        Text("\(viewModel.brief.benefits.count)/\(ScriptBrief.maxBenefits)")
    }

    // Paso 2
    private var styleStep: some View {
        VStack(spacing: 16) {
            FormCard(title: "Duración del reel") {
                Picker("Duración", selection: $viewModel.brief.duration) {
                    ForEach(ScriptDuration.allCases, id: \.self) { duration in
                        Text("\(duration.shortName) · \(duration.rawValue)").tag(duration)
                    }
                }
                .pickerStyle(.segmented)
            }

            FormCard(title: "Tipo de hook") {
                VStack(spacing: 8) {
                    ForEach(HookType.allCases, id: \.self) { hook in
                        HookOption(hook: hook, isSelected: viewModel.brief.hookType == hook) {
                            viewModel.brief.hookType = hook
                        }
                    }
                }
            }

            FormCard(title: "Tono") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 10)], spacing: 10) {
                    ForEach(ScriptTone.allCases, id: \.self) { tone in
                        SelectableChip(icon: nil, title: tone.rawValue, isSelected: viewModel.brief.tone == tone) {
                            viewModel.brief.tone = tone
                        }
                    }
                }
            }

            FormCard(title: "Guiones a generar") {
                Picker("Cantidad", selection: $viewModel.brief.count) {
                    ForEach(ScriptBrief.countRange, id: \.self) { Text("\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if !subscriptionManager.isSubscribed {
                quotaBanner
            }
        }
    }

    private var quotaBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: quota.remaining > 0 ? "gift.fill" : "lock.fill")
                .foregroundStyle(quota.remaining > 0 ? .green : Theme.accentStart)
            Text(quota.remaining > 0
                 ? "Te quedan \(quota.remaining) de \(ScriptQuota.freeMonthlyGenerations) generaciones gratis este mes"
                 : "Has usado tus generaciones gratis de este mes")
                .font(.footnote)
                .foregroundStyle(Theme.secondary(scheme))
            Spacer(minLength: 0)
            Button("Pro") { viewModel.showPaywall = true }
                .font(.footnote.weight(.bold))
                .foregroundStyle(Theme.accentStart)
        }
        .padding(14)
        .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // Paso 3
    private var resultsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(viewModel.results.count == 1 ? "Tu guion está listo" : "\(viewModel.results.count) guiones listos")
                .font(.title3.bold())
                .foregroundStyle(Theme.primary(scheme))
            Text("Guardados en «Mis guiones». Ábrelos para leerlos en el teleprompter o exportarlos.")
                .font(.footnote)
                .foregroundStyle(Theme.secondary(scheme))

            ForEach(viewModel.results) { script in
                ScriptRow(script: script) { selectedScript = script }
            }
        }
    }

    // Barra inferior
    @ViewBuilder
    private var bottomBar: some View {
        HStack(spacing: 12) {
            switch viewModel.step {
            case .business:
                PrimaryButton(title: "Continuar", icon: "arrow.right") {
                    focusedField = nil
                    viewModel.continueToStyle()
                }
            case .style:
                SecondaryButton(icon: "chevron.left", label: "Atrás") { viewModel.back() }
                PrimaryButton(title: viewModel.brief.count == 1 ? "Generar guion" : "Generar \(viewModel.brief.count) guiones",
                              icon: "wand.and.stars") {
                    runWithAIConsent($pendingAIAction) { Task { await viewModel.generate() } }
                }
            case .results:
                SecondaryButton(icon: "square.and.pencil", label: "Nuevo brief") { viewModel.startOver() }
                PrimaryButton(title: "Generar otros", icon: "arrow.clockwise") {
                    runWithAIConsent($pendingAIAction) { Task { await viewModel.generate() } }
                }
            }
        }
        .disabled(viewModel.isGenerating)
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Biblioteca

    @ViewBuilder
    private var libraryList: some View {
        if library.scripts.isEmpty {
            ContentUnavailableView {
                Label("Aún no tienes guiones", systemImage: "doc.text")
            } description: {
                Text("Los guiones que generes se guardan aquí automáticamente.")
            } actions: {
                Button("Crear el primero") { mode = .create }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentStart)
            }
        } else {
            List {
                ForEach(library.scripts) { script in
                    ScriptRow(script: script) { selectedScript = script }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions {
                            Button(role: .destructive) { library.delete(script) } label: {
                                Label("Borrar", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

// MARK: - Componentes

private struct StepIndicator: View {
    let current: UGCScriptViewModel.Step
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(UGCScriptViewModel.Step.allCases, id: \.self) { step in
                let reached = step.rawValue <= current.rawValue
                VStack(spacing: 6) {
                    Capsule()
                        .fill(reached ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.subtleStroke(scheme)))
                        .frame(height: 4)
                    Text(step.title)
                        .font(.caption.weight(step == current ? .semibold : .regular))
                        .foregroundStyle(reached ? Theme.primary(scheme) : Theme.secondary(scheme))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Paso \(current.rawValue + 1) de \(UGCScriptViewModel.Step.allCases.count): \(current.title)")
    }
}

private struct FormCard<Content: View>: View {
    let title: String
    var trailing: Text? = nil
    @ViewBuilder let content: Content
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Theme.primary(scheme))
                Spacer()
                trailing?
                    .font(.caption)
                    .foregroundStyle(Theme.secondary(scheme))
            }
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.subtleStroke(scheme)))
    }
}

private struct InputField: View {
    let title: String?
    let placeholder: String
    @Binding var text: String
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.secondary(scheme))
            }
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...3)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

private struct SelectableChip: View {
    let icon: String?
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(.title3)
                }
                Text(title)
                    .font(.caption.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: icon == nil ? 40 : 70)
            .padding(.horizontal, 6)
            .foregroundStyle(isSelected ? .white : Theme.primary(scheme))
            .background(
                isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.panel(scheme)),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct HookOption: View {
    let hook: HookType
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: hook.icon)
                    .font(.body)
                    .foregroundStyle(isSelected ? .white : Theme.accentStart)
                    .frame(width: 36, height: 36)
                    .background(
                        isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.accentStart.opacity(0.12)),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(hook.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primary(scheme))
                    Text(hook.description)
                        .font(.caption)
                        .foregroundStyle(Theme.secondary(scheme))
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Theme.accentStart : Theme.subtleStroke(scheme))
            }
            .padding(10)
            .background(isSelected ? Theme.accentStart.opacity(0.08) : .clear,
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct ScriptRow: View {
    let script: UGCScript
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Text(script.title)
                        .font(.headline)
                        .foregroundStyle(Theme.primary(scheme))
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Label("\(script.hookScore)", systemImage: "flame.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                }
                Text(script.hook)
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondary(scheme))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 12) {
                    Label("~\(script.estimatedSeconds) s", systemImage: "clock")
                    Label("\(script.shotList.count) tomas", systemImage: "camera")
                    Spacer()
                    Text(script.createdAt.formatted(.relative(presentation: .named).locale(Locale(identifier: "es_ES"))))
                }
                .font(.caption)
                .foregroundStyle(Theme.secondary(scheme))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.subtleStroke(scheme)))
        }
        .buttonStyle(.plain)
    }
}

private struct PrimaryButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(.white)
        }
    }
}

private struct SecondaryButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.headline)
                .padding(.vertical, 15)
                .padding(.horizontal, 18)
                .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .foregroundStyle(Theme.primary(scheme))
        }
    }
}

#Preview {
    UGCScriptMakerView()
        .environmentObject(SubscriptionManager.shared)
}
