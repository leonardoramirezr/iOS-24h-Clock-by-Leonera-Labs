import Foundation

extension Int {
    /// Remainder of the division that is always in `0..<modulus`.
    func positiveModulo(_ modulus: Int) -> Int {
        let remainder = self % modulus
        return remainder < 0 ? remainder + modulus : remainder
    }
}

extension Double {
    /// Remainder of the division that is always in `0..<modulus`.
    func positiveModulo(_ modulus: Double) -> Double {
        let remainder = truncatingRemainder(dividingBy: modulus)
        return remainder < 0 ? remainder + modulus : remainder
    }
}

enum Interpolation {
    /// Hermite interpolation between 0 and 1 when `value` goes from `lower` to `upper`.
    static func smoothstep(_ lower: Double, _ upper: Double, _ value: Double) -> Double {
        guard upper != lower else { return value < lower ? 0 : 1 }
        let progress = min(max((value - lower) / (upper - lower), 0), 1)
        return progress * progress * (3 - 2 * progress)
    }
}
