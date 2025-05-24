import Foundation

struct AccountDTO: Codable {
    let accountNumber: String
    let label: String
    let value: Double
    let positions: [PositionDTO]
}
