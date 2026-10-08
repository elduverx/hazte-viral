import SwiftUI

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

