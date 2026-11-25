import Testing
@testable import GuitarAppFinal

struct MoodColorTests {
    /// Hue → hex pairs from M2-PLAN.md (oklch(0.80 0.11 hue) converted by the design tool).
    @Test(arguments: [
        (10.0, UInt32(0xFBA0AD)),
        (290, 0xBCB2FF),
        (95, 0xD4BD67),
        (50, 0xF7A97C),
        (245, 0x7FC5FF),
        (80, 0xE3B667),
        (200, 0x56D3DA),
        (330, 0xE6A4E0),
        (150, 0x89D298),
    ])
    func hueMatchesDesignHex(hue: Double, expected: UInt32) {
        let actual = MoodColor.hex(hue: hue)
        // Allow ±2 per channel for rounding differences between converters.
        for shift in [16, 8, 0] as [UInt32] {
            let a = Int((actual >> shift) & 0xFF)
            let e = Int((expected >> shift) & 0xFF)
            #expect(abs(a - e) <= 2, "hue \(hue): got \(String(actual, radix: 16)), want \(String(expected, radix: 16))")
        }
    }
}
