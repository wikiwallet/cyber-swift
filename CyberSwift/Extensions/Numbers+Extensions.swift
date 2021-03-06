//
//  Numbers+Extensions.swift
//  CyberSwift
//
//  Created by Sergey Monastyrskiy on 21.11.2019.
//  Copyright © 2019 Commun Limited. All rights reserved.
//

import Foundation

extension CGFloat {
    public static func adaptive(width: CGFloat) -> CGFloat {
        (width * Config.widthRatio).rounded(.down)
    }

    public static func adaptive(height: CGFloat) -> CGFloat {
        (height * Config.heightRatio).rounded(.down)
    }
}

extension Formatter {
    static let withSeparator: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.groupingSeparator = " "
        formatter.numberStyle = .decimal
        return formatter
    }()
}

extension UInt64 {
    public var formattedWithSeparator: String {
        Formatter.withSeparator.string(for: self) ?? ""
    }
}

extension FloatingPoint {
    public var whole: Self { modf(self).0 }
    public var fraction: Self { modf(self).1 }

    public var formattedWithSeparator: String {
        guard self >= 1_000 else { return "\(self)" }
        return Formatter.withSeparator.string(for: self) ?? ""
    }
}
