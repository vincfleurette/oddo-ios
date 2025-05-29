import SwiftUI

struct PortfolioOverviewView: View {
    let portfolio: PortfolioStats
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Résumé global
                GlobalSummaryCard(portfolio: portfolio)
                
                // Performance par classe d'actif
                AssetClassesCard(assetClasses: portfolio.performanceByAssetClass)
                
                // Top et worst performers
                PerformersCard(
                    topPerformers: portfolio.topPerformers,
                    worstPerformers: portfolio.worstPerformers
                )
            }
            .padding()
        }
        .navigationTitle("Portfolio Overview")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Global Summary Card

struct GlobalSummaryCard: View {
    let portfolio: PortfolioStats
    
    var body: some View {
        VStack(spacing: 16) {
            // Titre
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.blue)
                Text("Portfolio Summary")
                    .font(.headline)
                Spacer()
            }
            
            // Valeur totale
            HStack {
                VStack(alignment: .leading) {
                    Text("Total Value")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(portfolio.formatted.totalValue)
                        .font(.title)
                        .fontWeight(.bold)
                }
                Spacer()
            }
            
            // Performance et P&L
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Performance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: portfolio.weightedPerformance >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        Text(portfolio.formatted.weightedPerformance)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(portfolio.formatted.performanceColor == "green" ? .green : .red)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Unrealized P&L")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(portfolio.formatted.totalPMVL)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(portfolio.formatted.pmvlColor == "green" ? .green : .red)
                }
            }
            
            // Statistiques additionnelles
            HStack {
                Spacer()
                VStack {
                    Text("\(portfolio.accountsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Accounts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack {
                    Text("\(portfolio.positionsCount)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Positions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Asset Classes Card

struct AssetClassesCard: View {
    let assetClasses: [String: AssetClassStats]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "building.columns.fill")
                    .foregroundColor(.green)
                Text("Asset Classes")
                    .font(.headline)
                Spacer()
            }
            
            if assetClasses.isEmpty {
                Text("No asset class data available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(assetClasses.sorted(by: { $0.value.totalValue > $1.value.totalValue })), id: \.key) { assetClass, stats in
                    AssetClassRow(name: assetClass, stats: stats)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AssetClassRow: View {
    let name: String
    let stats: AssetClassStats
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("\(stats.positionsCount) positions")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(stats.formatted.totalValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(stats.formatted.averagePerformance)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(stats.formatted.performanceColor == "green" ? .green : .red)
                }
            }
            
            // Barre de progression pour la valeur relative
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: geometry.size.width * min(stats.totalWeight / 100, 1.0))
                    
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 4)
            .cornerRadius(2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Performers Card

struct PerformersCard: View {
    let topPerformers: [PerformerPosition]
    let worstPerformers: [PerformerPosition]
    @State private var showingTopPerformers = true
    
    var body: some View {
        VStack(spacing: 12) {
            // Header avec sélecteur
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                
                Picker("Performers", selection: $showingTopPerformers) {
                    Text("Top Performers").tag(true)
                    Text("Worst Performers").tag(false)
                }
                .pickerStyle(.segmented)
            }
            
            // Liste des performers
            let performers = showingTopPerformers ? topPerformers : worstPerformers
            
            if performers.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                ForEach(Array(performers.enumerated()), id: \.offset) { index, performer in
                    PerformerRow(performer: performer, rank: index + 1)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct PerformerRow: View {
    let performer: PerformerPosition
    let rank: Int
    
    var body: some View {
        HStack {
            // Rang
            Text("\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.blue))
            
            // Informations de la position
            VStack(alignment: .leading, spacing: 2) {
                Text(performer.libInstrument)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                Text(performer.classActif)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Performance et valeur
            VStack(alignment: .trailing, spacing: 2) {
                Text(performer.formatted.performance)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(performer.formatted.performanceColor == "green" ? .green : .red)
                
                Text(performer.formatted.value)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
