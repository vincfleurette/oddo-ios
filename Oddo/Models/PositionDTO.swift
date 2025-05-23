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
}
