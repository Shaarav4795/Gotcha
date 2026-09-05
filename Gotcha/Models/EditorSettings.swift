import SwiftUI

struct EditorSettings: Hashable, Codable {
    var captionSize: Double = 22
    var captionPosition: CGPoint = CGPoint(x: 0.5, y: 0.82)
    var captionWeight: CaptionWeight = .bold
    var captionAlign: TextAlign = .center
    var captionCase: TextCaseOption = .none

    var subtitlesOn: Bool = true
    var subtitleSize: Double = 13
    var subtitlePosition: CGPoint = CGPoint(x: 0.5, y: 0.92)

    var aspect: Aspect = .portrait
    var waveformStyle: WaveformStyle = .bars
    var waveformPosition: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var waveformSensitivity: Double = 100

    var volume: Double = 1.0

    var loop: Bool = true
}

enum Aspect: String, CaseIterable, Identifiable, Hashable, Codable {
    case portrait, square, landscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portrait: return "9:16"
        case .square: return "1:1"
        case .landscape: return "16:9"
        }
    }

    var ratio: CGFloat {
        switch self {
        case .portrait: return 9 / 16
        case .square: return 1
        case .landscape: return 16 / 9
        }
    }
}

enum WaveformStyle: String, CaseIterable, Identifiable, Hashable, Codable {
    case bars, line

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

enum CaptionWeight: String, CaseIterable, Identifiable, Hashable, Codable {
    case regular, medium, bold, heavy

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var weight: Font.Weight {
        switch self {
        case .regular: return .regular
        case .medium: return .medium
        case .bold: return .bold
        case .heavy: return .heavy
        }
    }
}

enum TextAlign: String, CaseIterable, Identifiable, Hashable, Codable {
    case leading, center, trailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Centre"
        case .trailing: return "Right"
        }
    }

    var alignment: TextAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }

    var horizontal: HorizontalAlignment {
        switch self {
        case .leading: return .leading
        case .center: return .center
        case .trailing: return .trailing
        }
    }
}

enum TextCaseOption: String, CaseIterable, Identifiable, Hashable, Codable {
    case none, uppercase, lowercase

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "Aa"
        case .uppercase: return "AA"
        case .lowercase: return "aa"
        }
    }

    var textCase: Text.Case? {
        switch self {
        case .none: return nil
        case .uppercase: return .uppercase
        case .lowercase: return .lowercase
        }
    }
}

