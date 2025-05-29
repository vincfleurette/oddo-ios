import Foundation

struct PositionDTO: Codable {
    let isinCode: String
    let libInstrument: String
    let valorisationAchatNette: Double
    let valeurMarcheDeviseSecurite: Double
    let dateArrete: Date
    let quantityMinute: Double
    let pmvl: Double
    let pmvr: Double
    let weightMinute: Double
    let reportingAssetClassCode: String
    let performance: Double // Nouveau champ performance
    let classActif: String // Nouveau champ classe d'actif
    let closingPriceInListingCurrency: Double // Prix de clôture
    
    // Propriétés calculées pour l'affichage
    var formattedPerformance: String {
        return String(format: "%+.2f%%", performance)
    }
    
    var isPerformancePositive: Bool {
        return performance >= 0
    }
    
    var formattedPMVL: String {
        return String(format: "%+.2f €", pmvl)
    }
    
    var isPMVLPositive: Bool {
        return pmvl >= 0
    }
    
    var formattedMarketValue: String {
        return String(format: "%.2f €", valeurMarcheDeviseSecurite)
    }
    
    var formattedWeight: String {
        return String(format: "%.1f%%", weightMinute)
    }
}
