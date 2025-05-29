import Foundation

// Réponse complète de l'API /accounts
struct AccountsResponse: Codable {
    let accounts: [AccountDTO]
    let portfolio: PortfolioStats
}

struct AccountDTO: Codable {
    let accountNumber: String
    let label: String
    let value: Double
    let positions: [PositionDTO]
    let stats: AccountStats?
    
    // Propriétés calculées
    var displayLabel: String {
        return label.isEmpty ? accountNumber : label
    }
    
    var formattedValue: String {
        return String(format: "%.2f €", value)
    }
}

struct AccountStats: Codable {
    let totalPMVL: Double
    let weightedPerformance: Double
    let totalWeight: Double
    let positionsCount: Int
    let formatted: FormattedAccountStats
}

struct FormattedAccountStats: Codable {
    let totalPMVL: String
    let weightedPerformance: String
    let pmvlColor: String
    let performanceColor: String
}

struct PortfolioStats: Codable {
    let totalValue: Double
    let totalPMVL: Double
    let totalPMVR: Double
    let weightedPerformance: Double
    let totalWeight: Double
    let positionsCount: Int
    let accountsCount: Int
    let performanceByAssetClass: [String: AssetClassStats]
    let topPerformers: [PerformerPosition]
    let worstPerformers: [PerformerPosition]
    let lastUpdate: String
    let formatted: FormattedPortfolioStats
}

struct FormattedPortfolioStats: Codable {
    let totalValue: String
    let totalPMVL: String
    let weightedPerformance: String
    let pmvlColor: String
    let performanceColor: String
}

struct AssetClassStats: Codable {
    let totalValue: Double
    let totalWeight: Double
    let weightedPerformance: Double
    let positionsCount: Int
    let averagePerformance: Double
    let formatted: FormattedAssetClassStats
}

struct FormattedAssetClassStats: Codable {
    let averagePerformance: String
    let totalValue: String
    let performanceColor: String
}

struct PerformerPosition: Codable {
    let isinCode: String
    let libInstrument: String
    let performance: Double
    let valeurMarcheDeviseSecurite: Double
    let weightMinute: Double
    let accountNumber: String
    let classActif: String
    let formatted: FormattedPerformerPosition
}

struct FormattedPerformerPosition: Codable {
    let performance: String
    let value: String
    let weight: String
    let performanceColor: String
}
