import SwiftUI

struct AnalysisDetailRow: View {
    let icon: String
    let title: String
    let content: String
    
    @Environment(\.colorScheme) private var scheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(Theme.primary(scheme))
                Spacer()
            }
            
            Text(content)
                .font(.footnote)
                .foregroundStyle(Theme.primary(scheme))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 22)
        }
        .padding(.vertical, 2)
    }
}
