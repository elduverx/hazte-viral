//
//  UGCScriptMakerView.swift
//  goviiral
//
//  Created by Claude on 8/12/25.
//

import SwiftUI

struct UGCScriptMakerView: View {
    @StateObject private var viewModel = UGCScriptViewModel()
    @EnvironmentObject private var subscriptionManager: SubscriptionManager
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dismiss) private var dismiss
    
    private var textPrimary: Color { Theme.primary(scheme) }
    private var textSecondary: Color { Theme.secondary(scheme) }
    private var panel: Color { Theme.panel(scheme) }
    private var stroke: Color { Theme.subtleStroke(scheme) }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background(scheme).ignoresSafeArea()
                BackgroundGlow()
                
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        
                        if !subscriptionManager.isSubscribed {
                            subscriptionBanner
                        }
                        
                        businessInfoSection
                        contentConfigSection
                        
                        if !viewModel.generatedScripts.isEmpty {
                            generatedScriptsSection
                        }
                        
                        generateButton
                    }
                    .padding()
                }
            }
        }
        .alert("Error", isPresented: $viewModel.showError) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Error inesperado")
        }
        .sheet(isPresented: $viewModel.showScriptDetail) {
            if let script = viewModel.selectedScript {
                UGCScriptDetailView(script: script)
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Cerrar") {
                    dismiss()
                }
                .foregroundStyle(textPrimary)
            }
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI UGC Script Maker")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(textPrimary)
                    Text("Guiones virales para tu negocio")
                        .font(.subheadline)
                        .foregroundStyle(textSecondary)
                }
                Spacer()
                Image(systemName: "video.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.accentStart)
                    .padding(12)
                    .background(panel, in: Circle())
            }
            
            if !subscriptionManager.isSubscribed {
                HStack(spacing: 8) {
                    Image(systemName: "gift.fill")
                        .foregroundStyle(.green)
                    Text("3 guiones gratis al mes")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(textSecondary)
                    Spacer()
                    Text("Usados: \(viewModel.creditsManager.monthlyUsage)/3")
                        .font(.footnote)
                        .foregroundStyle(Theme.accentStart)
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var subscriptionBanner: some View {
        GlassCard {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Guiones ilimitados")
                        .font(.headline)
                        .foregroundStyle(textPrimary)
                    Text("Acceso a todos los nichos y exportación avanzada")
                        .font(.caption)
                        .foregroundStyle(textSecondary)
                }
                
                Spacer()
                
                Button("Suscribirse") {
                    // Show subscription paywall
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.accentStart)
                .foregroundStyle(.white)
                .cornerRadius(12)
            }
        }
    }
    
    private var businessInfoSection: some View {
        VStack(spacing: 0) {
            // Section Header with glass morphism
            HStack {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Theme.accentStart.opacity(0.8),
                                        Theme.accentEnd.opacity(0.9)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: Theme.accentStart.opacity(0.3), radius: 8, x: 0, y: 4)
                        
                        Image(systemName: "building.2.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Información del negocio")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(textPrimary)
                        
                        Text("Cuéntanos sobre tu empresa")
                            .font(.caption)
                            .foregroundStyle(textSecondary)
                    }
                }
                
                Spacer()
                
                // Progress indicator
                ZStack {
                    Circle()
                        .stroke(stroke.opacity(0.3), lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    Circle()
                        .trim(from: 0, to: businessFormProgress)
                        .stroke(Theme.accentStart, lineWidth: 2)
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: businessFormProgress)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(scheme == .dark ? 0.1 : 0.3),
                                Color.white.opacity(scheme == .dark ? 0.05 : 0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: Color.black.opacity(scheme == .dark ? 0.3 : 0.1),
                radius: 20,
                x: 0,
                y: 10
            )
            
            // Form Fields with enhanced glass cards
            VStack(spacing: 16) {
                // Business Niche Picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Nicho del negocio")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(textPrimary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(BusinessNiche.allCases, id: \.id) { niche in
                                EnhancedNicheCard(
                                    niche: niche,
                                    isSelected: viewModel.selectedNiche.id == niche.id
                                ) {
                                    viewModel.selectedNiche = niche
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
                
                EnhancedTextField(
                    icon: "storefront.fill",
                    title: "Tipo de negocio",
                    text: $viewModel.businessType,
                    placeholder: "Restaurante italiano, Clínica dental, Gimnasio...",
                    iconColor: .blue
                )
                
                EnhancedTextField(
                    icon: "tag.fill",
                    title: "Producto/Servicio específico",
                    text: $viewModel.productService,
                    placeholder: "Pizza artesanal, Blanqueamiento dental, Entrenamiento...",
                    iconColor: .green
                )
                
                EnhancedTextField(
                    icon: "person.3.fill",
                    title: "Público objetivo",
                    text: $viewModel.targetAudience,
                    placeholder: "Familias jóvenes 25-40 años, Mujeres profesionales...",
                    iconColor: .purple
                )
                
                // Key Benefits with enhanced design
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            Text("Beneficios clave")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(textPrimary)
                        }
                        
                        Spacer()
                        
                        if viewModel.keyBenefits.count < 5 {
                            Button {
                                viewModel.addBenefit()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.caption)
                                    Text("Agregar")
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.accentStart.opacity(0.1))
                                .foregroundStyle(Theme.accentStart)
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Theme.accentStart.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    ForEach(Array(viewModel.keyBenefits.enumerated()), id: \.offset) { index, benefit in
                        HStack(spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(Theme.accentStart, in: Circle())
                            
                            TextField("Beneficio importante de tu producto/servicio", text: $viewModel.keyBenefits[index])
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(stroke.opacity(0.5), lineWidth: 1)
                                )
                            
                            if viewModel.keyBenefits.count > 1 {
                                Button {
                                    viewModel.removeBenefit(at: index)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top, 20)
        }
    }
    
    private var businessFormProgress: Double {
        let fields = [viewModel.businessType, viewModel.productService, viewModel.targetAudience]
        let nicheSelected = !viewModel.selectedNiche.id.isEmpty ? 1 : 0
        let benefitsCount = viewModel.keyBenefits.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        
        let filledFields = fields.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let totalItems = fields.count + 1 + min(benefitsCount, 1) // 3 fields + niche + at least 1 benefit
        let completedItems = filledFields + nicheSelected + min(benefitsCount, 1)
        
        return Double(completedItems) / Double(totalItems)
    }
    
    private var contentConfigSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Configuración del contenido", systemImage: "slider.horizontal.3")
                    .font(.headline)
                    .foregroundStyle(textPrimary)
                
                VStack(alignment: .leading, spacing: 12) {
                    // Duration Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Duración del reel")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(textPrimary)
                        
                        Picker("Duración", selection: $viewModel.selectedDuration) {
                            ForEach(ScriptDuration.allCases, id: \.self) { duration in
                                Text(duration.displayName).tag(duration)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Hook Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tipo de hook")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(textPrimary)
                        
                        Menu {
                            ForEach(HookType.allCases, id: \.self) { hookType in
                                Button {
                                    viewModel.selectedHookType = hookType
                                } label: {
                                    VStack(alignment: .leading) {
                                        Text(hookType.rawValue)
                                        Text(hookType.description)
                                            .font(.caption)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.selectedHookType.rawValue)
                                        .foregroundStyle(textPrimary)
                                    Text(viewModel.selectedHookType.description)
                                        .font(.caption)
                                        .foregroundStyle(textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundStyle(textSecondary)
                            }
                            .padding()
                            .background(panel, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(stroke))
                        }
                    }
                    
                    // Tone
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tono del contenido")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(textPrimary)
                        
                        Picker("Tono", selection: $viewModel.selectedTone) {
                            ForEach(ScriptTone.allCases, id: \.self) { tone in
                                Text(tone.rawValue).tag(tone)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    
                    // Script Count
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Número de guiones")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(textPrimary)
                        
                        HStack {
                            Stepper(value: $viewModel.scriptCount, in: 1...10) {
                                Text("\(viewModel.scriptCount) guion\(viewModel.scriptCount == 1 ? "" : "es")")
                                    .foregroundStyle(textPrimary)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var generateButton: some View {
        Button {
            Task {
                await viewModel.generateScripts()
            }
        } label: {
            HStack {
                if viewModel.isGenerating {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(0.9)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                
                Text(viewModel.isGenerating ? "Generando guiones..." : "Generar \(viewModel.scriptCount) guión\(viewModel.scriptCount == 1 ? "" : "es")")
                    .fontWeight(.bold)
                
                Spacer()
            }
            .font(.title3)
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.recordRed)
            .foregroundStyle(.white)
            .cornerRadius(18)
            .shadow(color: Color.red.opacity(0.3), radius: 16, y: 8)
        }
        .disabled(viewModel.isGenerating)
        .opacity(viewModel.isGenerating ? 0.7 : 1)
    }
    
    private var generatedScriptsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label("Guiones generados", systemImage: "list.bullet.below.rectangle")
                        .font(.headline)
                        .foregroundStyle(textPrimary)
                    
                    Spacer()
                    
                    Button {
                        viewModel.clearForm()
                    } label: {
                        Text("Limpiar")
                            .font(.caption)
                            .foregroundStyle(Theme.accentStart)
                    }
                }
                
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.generatedScripts) { script in
                        ScriptCard(script: script) {
                            viewModel.selectScript(script)
                        }
                    }
                }
            }
        }
    }
}

struct NicheCard: View {
    let niche: BusinessNiche
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Image(systemName: niche.icon)
                    .font(.title2)
                    .foregroundStyle(isSelected ? .white : Theme.accentStart)
                
                Text(niche.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? .white : Theme.primary(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(minWidth: 100)
            .background(
                isSelected ? Theme.accentStart : Theme.panel(scheme),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Theme.accentStart : Theme.subtleStroke(scheme))
            )
        }
        .buttonStyle(.plain)
    }
}

struct CustomTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.primary(scheme))
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct ScriptCard: View {
    let script: UGCScript
    let onTap: () -> Void
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(script.title)
                            .font(.headline)
                            .foregroundStyle(Theme.primary(scheme))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text(script.duration.displayName)
                            .font(.caption)
                            .foregroundStyle(Theme.secondary(scheme))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(script.hookScore)")
                                .font(.headline.bold())
                                .foregroundStyle(.orange)
                        }
                        
                        Text("Hook Score")
                            .font(.caption2)
                            .foregroundStyle(Theme.secondary(scheme))
                    }
                }
                
                Text(script.hook)
                    .font(.subheadline)
                    .foregroundStyle(Theme.primary(scheme))
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack {
                    Label("\(script.shotList.count) tomas", systemImage: "camera.fill")
                    
                    Spacer()
                    
                    Label("\(script.subtitles.count) subtítulos", systemImage: "text.bubble.fill")
                }
                .font(.caption)
                .foregroundStyle(Theme.secondary(scheme))
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Theme.panel(scheme), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.subtleStroke(scheme)))
        }
        .buttonStyle(.plain)
    }
}

struct EnhancedTextField: View {
    let icon: String
    let title: String
    @Binding var text: String
    let placeholder: String
    let iconColor: Color
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primary(scheme))
            }
            
            TextField(placeholder, text: $text)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    .ultraThinMaterial,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(scheme == .dark ? 0.1 : 0.2),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(
                    color: Color.black.opacity(scheme == .dark ? 0.2 : 0.05),
                    radius: 8,
                    x: 0,
                    y: 2
                )
        }
    }
}

struct EnhancedNicheCard: View {
    let niche: BusinessNiche
    let isSelected: Bool
    let onTap: () -> Void
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            isSelected
                            ? LinearGradient(
                                colors: [Theme.accentStart, Theme.accentEnd],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : LinearGradient(
                                colors: [Color.clear, Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    isSelected ? Color.clear : Theme.subtleStroke(scheme),
                                    lineWidth: 1
                                )
                        )
                    
                    Image(systemName: niche.icon)
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : Theme.accentStart)
                }
                
                Text(niche.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isSelected ? Theme.accentStart : Theme.primary(scheme))
                    .multilineTextAlignment(.center)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .frame(minWidth: 100)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        isSelected
                        ? LinearGradient(
                            colors: [Theme.accentStart.opacity(0.5), Theme.accentStart.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                            colors: [
                                Color.white.opacity(scheme == .dark ? 0.1 : 0.2),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: isSelected
                ? Theme.accentStart.opacity(0.3)
                : Color.black.opacity(scheme == .dark ? 0.2 : 0.05),
                radius: isSelected ? 12 : 6,
                x: 0,
                y: isSelected ? 4 : 2
            )
            .scaleEffect(isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    UGCScriptMakerView()
        .environmentObject(SubscriptionManager.shared)
}