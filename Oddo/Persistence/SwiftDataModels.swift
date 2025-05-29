import Foundation
import SwiftData

@Model
class Account {
    @Attribute(.unique) var accountNumber: String
    var label: String
    var value: Double
    @Relationship(deleteRule: .cascade, inverse: \Position.account)
    var positions: [Position]

    init(accountNumber: String, label: String, value: Double, positions: [Position] = []) {
        self.accountNumber = accountNumber
        self.label = label
        self.value = value
        self.positions = positions
        
        // S'assurer que les positions pointent vers ce compte
        for position in positions {
            position.account = self
        }
    }
}

@Model
class Position {
    @Attribute(.unique) var id = UUID()
    var isinCode: String
    var libInstrument: String
    var valorisationAchatNette: Double
    var valeurMarcheDeviseSecurite: Double
    var dateArrete: Date
    var quantityMinute: Double
    var pmvl: Double
    var pmvr: Double
    var weightMinute: Double
    var reportingAssetClassCode: String
    
    // Nouveaux champs performance
    var performance: Double
    var classActif: String
    var closingPriceInListingCurrency: Double
    
    // Relation inverse vers Account
    @Relationship var account: Account?

    init(dto: PositionDTO, account: Account? = nil) {
        self.id = UUID()
        self.isinCode = dto.isinCode
        self.libInstrument = dto.libInstrument
        self.valorisationAchatNette = dto.valorisationAchatNette
        self.valeurMarcheDeviseSecurite = dto.valeurMarcheDeviseSecurite
        self.dateArrete = dto.dateArrete
        self.quantityMinute = dto.quantityMinute
        self.pmvl = dto.pmvl
        self.pmvr = dto.pmvr
        self.weightMinute = dto.weightMinute
        self.reportingAssetClassCode = dto.reportingAssetClassCode
        
        // Nouveaux champs
        self.performance = dto.performance
        self.classActif = dto.classActif
        self.closingPriceInListingCurrency = dto.closingPriceInListingCurrency
        
        self.account = account
    }
    
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

@Model
class Snapshot {
    @Attribute(.unique) var id = UUID()
    var timestamp: Date
    var accountNumber: String
    var value: Double
    var positionsData: Data

    init(account: Account) {
        self.timestamp = Date()
        self.accountNumber = account.accountNumber
        self.value = account.value
        let encoder = JSONEncoder()
        
        // Configuration de l'encoder pour les dates
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        encoder.dateEncodingStrategy = .formatted(dateFormatter)
        
        do {
            self.positionsData = try encoder.encode(account.positions.map { pos in
                PositionDTO(
                    isinCode: pos.isinCode,
                    libInstrument: pos.libInstrument,
                    valorisationAchatNette: pos.valorisationAchatNette,
                    valeurMarcheDeviseSecurite: pos.valeurMarcheDeviseSecurite,
                    dateArrete: pos.dateArrete,
                    quantityMinute: pos.quantityMinute,
                    pmvl: pos.pmvl,
                    pmvr: pos.pmvr,
                    weightMinute: pos.weightMinute,
                    reportingAssetClassCode: pos.reportingAssetClassCode,
                    performance: pos.performance,
                    classActif: pos.classActif,
                    closingPriceInListingCurrency: pos.closingPriceInListingCurrency
                )
            })
        } catch {
            print("❌ Error encoding positions for snapshot: \(error)")
            self.positionsData = Data()
        }
    }
}
