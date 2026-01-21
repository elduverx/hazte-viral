import SwiftUI

struct StatCard: View {
    let icon: String
    let label: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.bold())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct TipCategory: View {
    let icon: String
    let title: String
    let tips: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.bold())
            }
            
            ForEach(Array(tips.enumerated()), id: \.offset) { index, tip in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .foregroundStyle(Theme.accent)
                        .font(.subheadline.bold())
                    Text(tip)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

struct BenchmarkRow: View {
    let metric: String
    let yourScore: Int
    let average: Int
    
    @Environment(\.colorScheme) private var scheme
    
    private var performance: (color: Color, text: String) {
        let diff = yourScore - average
        if diff > 15 {
            return (.green, "Excellent")
        } else if diff > 0 {
            return (.blue, "Above Average")
        } else if diff > -15 {
            return (.orange, "Room for Growth")
        } else {
            return (.red, "Needs Work")
        }
    }
    
    var body: some View {
        HStack {
            Text(metric)
                .font(.caption)
                .frame(width: 80, alignment: .leading)
            
            Text("\(yourScore)%")
                .font(.caption.bold())
                .foregroundStyle(performance.color)
                .frame(width: 40, alignment: .trailing)
            
            Text("vs \(average)%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 50, alignment: .leading)
            
            Spacer()
            
            Text(performance.text)
                .font(.caption2.bold())
                .foregroundStyle(performance.color)
        }
    }
}
