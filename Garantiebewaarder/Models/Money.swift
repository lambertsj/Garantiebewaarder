import Foundation

/// Conversie tussen `Decimal` en gehele centen (veilige opslagvorm).
enum Money {
    /// Rondt af op hele centen. `nil` bij negatieve of onbruikbare waarden.
    static func cents(from amount: Decimal) -> Int? {
        guard amount >= 0 else { return nil }
        var value = amount * 100
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 0, .plain)
        let number = NSDecimalNumber(decimal: rounded)
        guard number != NSDecimalNumber.notANumber,
              number.compare(NSDecimalNumber(value: Int.max)) == .orderedAscending
        else { return nil }
        return number.intValue
    }

    static func decimal(fromCents cents: Int) -> Decimal {
        Decimal(cents) / 100
    }
}
