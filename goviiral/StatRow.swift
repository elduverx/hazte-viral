import SwiftUI

struct StatRow: View {
    let metric: String
    let yourScore: Int
    let average: Int
    let icon: String
    
    @Environment(\.colorScheme) private var scheme
    
    private var performance: (color: Color, text: String) {
        let diff = yourScore - average
        if diff > 15 {
            return (.green, "Excelente")
        } else if diff > 0 {
            return (.blue, "Sobre Promedio")
        } else if diff > -15 {
            return (.orange, "Puede Mejorar")
        } else {
            return (.red, "Necesita Trabajo")
        }
    }
    
    private var scoreColor: Color {
        if yourScore >= 80 { return .green }
        else if yourScore >= 60 { return .blue }
        else if yourScore >= 40 { return .orange }
        else { return .red }
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Ícono y métrica
            HStack(spacing: 6) {
                Text(icon)
                    .font(.caption)
                Text(metric)
                    .font(.caption)
                    .foregroundStyle(Theme.primary(scheme))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Tu puntuación
            Text("\(yourScore)%")
                .font(.caption.bold())
                .foregroundStyle(scoreColor)
                .frame(width: 60, alignment: .center)
            
            // Promedio
            Text("\(average)%")
                .font(.caption)
                .foregroundStyle(Theme.secondary(scheme))
                .frame(width: 60, alignment: .center)
            
            // Estado
            Text(performance.text)
                .font(.caption2.bold())
                .foregroundStyle(performance.color)
                .frame(width: 70, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}