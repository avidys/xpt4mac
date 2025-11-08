import UniformTypeIdentifiers

extension UTType {
    static var sasXPT: UTType {
        // Use exportedAs since we declare this type in Info.plist
        UTType(exportedAs: "com.avidys.XPTMacViewer.xpt")
    }
}
