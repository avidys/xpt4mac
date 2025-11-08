import SwiftUI

struct DataTableView: View {
    let dataset: XPTDataset
    @State private var statisticsByVariable: [UUID: VariableStatistics] = [:]
    @ObservedObject private var settings = AppSettings.shared
    private let tableTheme: DataTableTheme

    @StateObject private var horizontalScrollState: HorizontalScrollState
    @State private var selectedVariable: XPTVariable?
    
    // Cache column widths to avoid recalculating on every render
    @State private var cachedColumnWidths: [UUID: CGFloat] = [:]

    private struct ColumnSummary {
        let typeDescription: String
        let missingDescription: String
        let uniqueDescription: String
    }
    
    init(dataset: XPTDataset, theme: DataTableTheme, maxColumnLength: Int = 40) {
        self.dataset = dataset
        self.tableTheme = theme
        _horizontalScrollState = StateObject(wrappedValue: HorizontalScrollState())
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section(header: headerRow) {
                        ForEach(Array(dataset.rows.enumerated()), id: \.1.id) { index, row in
                            tableRow(index: index, row: row)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            horizontalScrollIndicator
                .padding(.horizontal, columnSpacing)
                .padding(.vertical, 4)
        }
        .background(tableTheme.containerBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .popover(item: $selectedVariable) { variable in
            NavigationStack {
                AsyncStatisticsView(variable: variable, dataset: dataset, cachedStatistics: statisticsByVariable[variable.id])
            }
        }
        .onAppear {
            // Pre-calculate column widths once when view appears
            calculateColumnWidths()
            // Calculate statistics in background if header statistics are enabled
            if settings.showHeaderStatistics {
                calculateStatisticsForHeaders()
            }
        }
        .onChange(of: settings.maxColumnLength) { _ in
            // Recalculate when max column length changes
            calculateColumnWidths()
        }
        .onChange(of: settings.showHeaderStatistics) { enabled in
            // Calculate statistics when setting is enabled
            if enabled {
                calculateStatisticsForHeaders()
            } else {
                // Clear statistics when disabled to save memory
                statisticsByVariable.removeAll()
                // Recalculate column widths without statistics
                calculateColumnWidths()
            }
        }
        .onChange(of: statisticsByVariable.count) { _ in
            // Recalculate column widths when statistics are updated
            // This ensures header text is accounted for in column width
            calculateColumnWidths()
        }
    }
    

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(pinnedVariables) { variable in
                headerButton(for: variable)
                    .frame(width: width(for: variable), alignment: .topLeading)
                    .background(headerBackground)
            }

            SynchronizedHorizontalScrollView(state: horizontalScrollState) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(scrollableVariables) { variable in
                        headerButton(for: variable)
                            .frame(width: width(for: variable), alignment: .topLeading)
                            .background(headerBackground)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .id("horizontal-scroll-header") // Stable ID to prevent unnecessary recreation
            
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(headerBackground)
        .overlay(Divider(), alignment: .bottom)
    }

    private func tableRow(index: Int, row: XPTDataset.Row) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(pinnedVariables) { variable in
                dataCell(text: row.displayValue(for: variable))
                    .frame(width: width(for: variable), alignment: .leading)
                    .frame(minHeight: rowHeight)
                    .background(rowBackground(for: index))
            }

            SynchronizedHorizontalScrollView(state: horizontalScrollState) {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(scrollableVariables) { variable in
                        dataCell(text: row.displayValue(for: variable))
                            .frame(width: width(for: variable), alignment: .leading)
                            .frame(minHeight: rowHeight)
                            .background(rowBackground(for: index))
                    }
                }
            }
            .frame(minHeight: rowHeight)
            .frame(maxWidth: .infinity, alignment: .leading)
            .id("horizontal-scroll-\(row.id)") // Stable ID to prevent unnecessary recreation
        }
        .padding(.horizontal, 12)
        .overlay(Divider(), alignment: .bottom)
    }

    private func headerButton(for variable: XPTVariable) -> some View {
        let cachedStatistics = statisticsByVariable[variable.id]
        
        return Button {
            selectedVariable = variable
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(variable.name)
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .foregroundStyle(headerColor(for: .primary) ?? Color.primary)
                if settings.showColumnLabels, !variable.label.isEmpty {
                    Text(variable.label)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(headerColor(for: .secondary) ?? Color.secondary)
                }
                // Show detected type only when statistics are available
                if let cached = cachedStatistics {
                    Text("type: \(cached.detectedType.displayName)")
                        .font(.caption)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(headerColor(for: .secondary) ?? Color.secondary)
                }
                // Show missing and unique values below type if setting is enabled and statistics are cached
                if settings.showHeaderStatistics, let cached = cachedStatistics {
                    Text(missingText(from: cached))
                        .font(.caption2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(headerColor(for: .tertiary) ?? Color.secondary.opacity(0.7))
                    Text("unique: \(cached.uniqueCount.formatted())")
                        .font(.caption2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(headerColor(for: .tertiary) ?? Color.secondary.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.trailing, columnSpacing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func dataCell(text: String) -> some View {
        // Use maxColumnLength ONLY to determine if text should wrap
        // Never truncate - always wrap if text is longer than maxColumnLength
        let shouldWrap = text.count > settings.maxColumnLength
        if shouldWrap {
            // Wrap long text - column width will accommodate the wrapped content
            Text(text)
                .font(.system(.body, design: .monospaced))
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(nil)
                .padding(.trailing, columnSpacing)
        } else {
            // Short text - single line, no wrapping needed
            Text(text)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1)
                .padding(.trailing, columnSpacing)
        }
    }

    private func rowBackground(for index: Int) -> Color {
        index.isMultiple(of: 2) ? tableTheme.evenRowBackground : tableTheme.oddRowBackground
    }

    private func columnSummary(for variable: XPTVariable) -> ColumnSummary {
        // Use cached statistics if available, otherwise show lightweight info without full calculation
        if let cached = statisticsByVariable[variable.id] {
            // Full statistics available - use them
            let typeDescription = cached.detectedType.displayName
            let missingDescription = missingText(from: cached)
            let uniqueDescription = "unique: \(cached.uniqueCount.formatted())"
            
            return ColumnSummary(
                typeDescription: typeDescription,
                missingDescription: missingDescription,
                uniqueDescription: uniqueDescription
            )
        } else {
            // No statistics yet - show lightweight info without expensive calculations
            // Just show SAS type and basic counts without type detection or unique count
            let typeDescription = variable.type.displayName
            let missingDescription = "calculating..."
            let uniqueDescription = "calculating..."
            
            return ColumnSummary(
                typeDescription: typeDescription,
                missingDescription: missingDescription,
                uniqueDescription: uniqueDescription
            )
        }
    }

    private func missingText(from statistics: VariableStatistics) -> String {
        let percent = statistics.total == 0 ? 0 : Double(statistics.missing) / Double(statistics.total)
        let formattedPercent = percent.formatted(.percent.precision(.fractionLength(0...1)))
        return "miss: \(statistics.missing.formatted()) (\(formattedPercent))"
    }


    private var pinnedVariables: [XPTVariable] { [] }

    private var scrollableVariables: [XPTVariable] {
        dataset.variables
    }

    private func width(for variable: XPTVariable) -> CGFloat {
        // Use cached width if available, otherwise fallback to calculation
        if let cached = cachedColumnWidths[variable.id] {
            return cached
        }
        // Fallback calculation (shouldn't happen if onAppear worked)
        // Pass statistics if available to account for header width
        let stats = statisticsByVariable[variable.id]
        return CGFloat(variable.displayWidth(for: dataset, maxLength: settings.maxColumnLength, statistics: stats))
    }
    
    private func calculateColumnWidths() {
        // Calculate all column widths once and cache them
        var widths: [UUID: CGFloat] = [:]
        for variable in dataset.variables {
            // Pass statistics if available to account for header width
            let stats = statisticsByVariable[variable.id]
            let width = CGFloat(variable.displayWidth(for: dataset, maxLength: settings.maxColumnLength, statistics: stats))
            widths[variable.id] = width
        }
        cachedColumnWidths = widths
    }
    
    private func calculateStatisticsForHeaders() {
        // Calculate statistics for all variables in the background
        // This allows headers to show missing/unique counts when the setting is enabled
        let variables = dataset.variables
        let rows = dataset.rows
        
        Task.detached(priority: .userInitiated) {
            var newStatistics: [UUID: VariableStatistics] = [:]
            
            // Calculate statistics for each variable
            for variable in variables {
                let values = rows.map { row in
                    row.values[variable.id]
                }
                let stats = VariableStatistics(variable: variable, values: values)
                newStatistics[variable.id] = stats
            }
            
            // Update on main thread
            let finalStatistics = newStatistics
            await MainActor.run {
                statisticsByVariable = finalStatistics
            }
        }
    }

    private var horizontalScrollIndicator: some View {
        GeometryReader { geometry in
            HorizontalScrollBar(
                scrollState: horizontalScrollState,
                contentWidth: scrollableContentWidth,
                visibleWidth: geometry.size.width
            )
        }
        .frame(height: 16)
    }

    private var scrollableContentWidth: CGFloat {
        // Use cached widths for performance
        max(scrollableVariables.reduce(0) { $0 + width(for: $1) + columnSpacing }, 1)
    }

    private enum Constants {
        /// Height of each data row in points
        static let rowHeight: CGFloat = 32
        /// Horizontal spacing between columns in points
        static let columnSpacing: CGFloat = 12
        /// Minimum column width in points
        static let minColumnWidth: CGFloat = 140
        /// Character width multiplier for column width calculation
        static let characterWidthMultiplier: CGFloat = 14
    }
    
    private var rowHeight: CGFloat { Constants.rowHeight }

    private var headerBackground: AnyShapeStyle {
        tableTheme.headerBackground
    }

    private var columnSpacing: CGFloat { Constants.columnSpacing }
}

/// A view that loads variable statistics asynchronously when displayed
/// This defers expensive calculations until the popover is actually opened
private struct AsyncStatisticsView: View {
    let variable: XPTVariable
    let dataset: XPTDataset
    let cachedStatistics: VariableStatistics?
    
    @State private var statistics: VariableStatistics?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let statistics = statistics {
                VariableStatisticsView(statistics: statistics)
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Calculating statistics...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                // Show basic info immediately while loading
                VStack(alignment: .leading, spacing: 16) {
                    Text("Variable: \(variable.name)")
                        .font(.headline)
                    if !variable.label.isEmpty {
                        Text("Label: \(variable.label)")
                            .font(.subheadline)
                    }
                    ProgressView()
                        .padding(.top)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
        .task {
            await loadStatistics()
        }
    }
    
    private func loadStatistics() async {
        // Use cached if available
        if let cached = cachedStatistics {
            statistics = cached
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        // Extract values and calculate statistics on background thread
        // This defers expensive work until the popover is actually opened
        let calculated = await Task.detached(priority: .userInitiated) {
            let values = dataset.rows.map { row in
                row.values[variable.id]
            }
            return VariableStatistics(variable: variable, values: values)
        }.value
        
        // Update on main thread
        await MainActor.run {
            statistics = calculated
        }
    }
}

private extension DataTableView {
    enum HeaderTextRole {
        case primary
        case secondary
        case tertiary
    }

    func headerColor(for role: HeaderTextRole) -> Color? {
        guard let base = tableTheme.headerTextColor else { return nil }
        switch role {
        case .primary:
            return base
        case .secondary:
            return base.opacity(0.8)
        case .tertiary:
            return base.opacity(0.65)
        }
    }
}

private extension XPTDataset.Row {
    func displayValue(for variable: XPTVariable) -> String {
        values[variable.id] ?? ""
    }
}

private extension XPTVariable {
    func displayWidth(for dataset: XPTDataset, maxLength: Int, statistics: VariableStatistics? = nil) -> Int {
        // Column width calculation based on actual content length
        // maxLength is ONLY used to determine wrapping - it does NOT limit column width
        // Column width should fit the actual content, not be capped by maxLength
        // Using realistic character width for monospaced fonts (typically 7-8 points)
        let characterWidthMultiplier: CGFloat = 7.5
        let minColumnWidth: CGFloat = 60
        let minCharacterWidth = 10 // Minimum 10 characters
        let padding: CGFloat = 24 // Padding for comfortable spacing
        
        // Start with variable name width
        var maxContentWidth = name.count
        
        // Check actual content values to determine the maximum content length
        // Find the longest value in the column (no capping by maxLength)
        for row in dataset.rows {
            if let value = row.values[self.id], !value.isEmpty {
                // Use actual value length - don't cap it
                // If value is longer than maxLength, it will wrap, but column width
                // should still accommodate the wrapped content width
                maxContentWidth = max(maxContentWidth, value.count)
            }
        }
        
        // Also consider label if it's longer
        if !label.isEmpty {
            maxContentWidth = max(maxContentWidth, label.count)
        }
        
        // Consider header statistics text if available
        if let stats = statistics {
            // Type text: "type: [TypeName]"
            let typeText = "type: \(stats.detectedType.displayName)"
            maxContentWidth = max(maxContentWidth, typeText.count)
            
            // Missing text: "miss: [count] ([percent])"
            // Estimate: "miss: " (6) + max count digits (e.g., "999,999" = 7) + " (" (2) + percent (e.g., "100.0%" = 6) + ")" (1) = ~22
            // But use actual calculation for accuracy
            let missingCount = stats.missing.formatted().count
            let missingPercent = stats.total == 0 ? 0 : Double(stats.missing) / Double(stats.total)
            let percentText = missingPercent.formatted(.percent.precision(.fractionLength(0...1)))
            let missingText = "miss: \(stats.missing.formatted()) (\(percentText))"
            maxContentWidth = max(maxContentWidth, missingText.count)
            
            // Unique text: "unique: [count]"
            // Estimate: "unique: " (9) + max count digits (e.g., "999,999" = 7) = ~16
            let uniqueText = "unique: \(stats.uniqueCount.formatted())"
            maxContentWidth = max(maxContentWidth, uniqueText.count)
        } else {
            // If statistics not available, estimate header width conservatively
            // "type: [TypeName]" - longest type name is probably "Integer" or "Factor" = ~12 chars
            maxContentWidth = max(maxContentWidth, "type: Integer".count)
            // "miss: 999 (100.0%)" - estimate ~20 chars
            maxContentWidth = max(maxContentWidth, "miss: 999 (100.0%)".count)
            // "unique: 999,999" - estimate ~16 chars
            maxContentWidth = max(maxContentWidth, "unique: 999,999".count)
        }
        
        // Column width is based on actual content width
        // maxLength is ONLY used for wrapping decision, not for width calculation
        // If content is 10 chars, column should be 10 chars wide (not 40)
        // If content is 100 chars and maxLength is 40, content will wrap at 40 chars per line
        // but column width should still accommodate the wrapped lines (maxLength wide)
        let effectiveWidth: Int
        if maxContentWidth > maxLength {
            // Content will wrap - column width should be maxLength wide
            effectiveWidth = maxLength
        } else {
            // Content fits in one line - use actual content width
            effectiveWidth = maxContentWidth
        }
        
        // Ensure minimum of 10 characters
        let finalWidth = max(effectiveWidth, minCharacterWidth)
        
        // Column width is based on effective content width
        // This ensures columns fit their content without unnecessary width
        let calculatedWidth = CGFloat(finalWidth) * characterWidthMultiplier + padding
        return max(Int(calculatedWidth), Int(minColumnWidth))
    }
}

private extension XPTDataset {
    func values(for variable: XPTVariable) -> [String?] {
        rows.map { row in
            row.values[variable.id]
        }
    }
}

/// A draggable horizontal scroll bar that allows users to scroll by dragging
private struct HorizontalScrollBar: View {
    @ObservedObject var scrollState: HorizontalScrollState
    let contentWidth: CGFloat
    let visibleWidth: CGFloat
    
    @State private var isDragging: Bool = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var dragStartPosition: CGFloat = 0
    
    private var scrollableWidth: CGFloat {
        max(contentWidth - visibleWidth, 0)
    }
    
    private var thumbWidth: CGFloat {
        guard contentWidth > visibleWidth, visibleWidth > 0 else { return visibleWidth }
        let ratio = visibleWidth / contentWidth
        return max(visibleWidth * ratio, 20) // Minimum thumb width of 20 points
    }
    
    private var trackWidth: CGFloat {
        visibleWidth
    }
    
    private var thumbPosition: CGFloat {
        guard scrollableWidth > 0, trackWidth > thumbWidth else { return 0 }
        let ratio = scrollState.offset / scrollableWidth
        return min(max(ratio * (trackWidth - thumbWidth), 0), trackWidth - thumbWidth)
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Track (background)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(0.2))
                .frame(width: trackWidth, height: 8)
            
            // Thumb (draggable)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.secondary.opacity(isDragging ? 0.8 : 0.5))
                .frame(width: thumbWidth, height: 8)
                .offset(x: thumbPosition)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragStartOffset = scrollState.offset
                                dragStartPosition = value.location.x
                            }
                            
                            let deltaX = value.location.x - dragStartPosition
                            let availableTrack = trackWidth - thumbWidth
                            guard availableTrack > 0 else { return }
                            
                            let ratio = deltaX / availableTrack
                            let newOffset = dragStartOffset + (ratio * scrollableWidth)
                            
                            // Clamp the offset
                            let clampedOffset = min(max(newOffset, 0), scrollableWidth)
                            scrollState.offset = clampedOffset
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
