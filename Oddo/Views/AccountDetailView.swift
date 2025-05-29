import SwiftUI
import SwiftData

struct AccountDetailView: View {
    let account: Account
    @Environment(\.modelContext) private var context
    @StateObject private var vm = AccountDetailViewModel()
    @State private var sortOption: PositionSortOption = .performance

    var body: some View {
        List {
            // En-tête avec résumé du compte
            Section {
                AccountSummaryCard(account: account)
            }
            
            // Sélecteur de tri
            Section {
                Picker("Sort by", selection: $sortOption) {
                    ForEach(PositionSortOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            // Liste des positions triées
            Section("Positions (\(sortedPositions.count))") {
                ForEach(sortedPositions) { position in
                    PositionRowView(position: position)
                }
            }
        }
        .navigationTitle(account.label.isEmpty ? account.accountNumber : account.label)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(NSLocalizedString("HistoryTitle", comment: "")) {
                    HistoryChartView(snapshots: vm.snapshots)
                }
            }
        }
        .task {
            await vm.load(account: account, context: context)
        }
    }
    
    private var sortedPositions: [Position] {
        vm.positions.sorted { pos1, pos2 in
            switch sortOption {
            case .performance:
                return pos1.performance > pos2.performance
            case .value:
                return pos1.valeurMarcheDeviseSecurite > pos2.valeurMarcheDeviseSecurite
            case .weight:
                return pos1.weightMinute > pos2.weightMinute
            case .name:
                return pos1.libInstrument < pos2.libInstrument
            case .pmvl:
                return pos1.pmvl > pos2.pmvl
            }
        }
    }
}

// MARK: - Position Sort Options

enum PositionSortOption: CaseIterable {
    case performance, value, weight, name, pmvl
    
    var displayName: String {
        switch self {
        case .performance: return "Performance"
        case .value: return "Value"
        case .weight: return "Weight"
        case .name: return "Name"
        case .pmvl: return "P&L"
        }
    }
}

// MARK: - Account Summary Card

struct AccountSummaryCard: View {
    let account: Account
    
    private var totalPerformance: Double {
        guard !account.positions.isEmpty else { return 0 }
        let weightedPerf = account.positions.reduce(0) { sum, position in
            sum + (position.performance * position.weightMinute / 100)
        }
        return weightedPerf
    }
    
    private var totalPMVL: Double {
        account.positions.reduce(0) { $0 + $1.pmvl }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Valeur totale
            HStack {
                Text("Total Value")
                    .font(.headline)
                Spacer()
                Text("\(account.value, specifier: "%.2f") €")
                    .font(.title2)
                    .fontWeight(.bold)
            }
            
            // Performance et P&L
            HStack {
                VStack(alignment: .leading) {
                    Text("Performance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%+.2f%%", totalPerformance))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(totalPerformance >= 0 ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("P&L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%+.2f €", totalPMVL))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(totalPMVL >= 0 ? .green : .red)
                }
            }
            
            // Nombre de positions
            HStack {
                Text("Positions")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(account.positions.count)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Position Row View

struct PositionRowView: View {
    let position: Position
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Ligne principale : nom et valeur
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(position.libInstrument)
                        .font(.headline)
                        .lineLimit(2)
                    
                    HStack {
                        Text(position.classActif)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(4)
                        
                        Text(position.isinCode)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(position.formattedMarketValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(position.formattedWeight)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Ligne de performance : performance et P&L
            HStack {
                // Performance
                HStack(spacing: 4) {
                    Image(systemName: position.isPerformancePositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(position.isPerformancePositive ? .green : .red)
                    
                    Text(position.formattedPerformance)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(position.isPerformancePositive ? .green : .red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((position.isPerformancePositive ? Color.green : Color.red).opacity(0.1))
                .cornerRadius(6)
                
                Spacer()
                
                // Plus/Moins value
                HStack(spacing: 4) {
                    Text("P&L:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(position.formattedPMVL)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(position.isPMVLPositive ? .green : .red)
                }
            }
            
            // Barre de progression pour le poids
            if position.weightMinute > 0 {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.blue.opacity(0.3))
                            .frame(width: geometry.size.width * min(position.weightMinute / 20, 1.0)) // Max 20% pour l'échelle
                        
                        Spacer(minLength: 0)
                    }
                }
                .frame(height: 3)
                .cornerRadius(1.5)
            }
        }
        .padding(.vertical, 4)
    }
}
