import Foundation

extension Double {
    var isInteger: Bool {
        isFinite && rounded() == self
    }
}
