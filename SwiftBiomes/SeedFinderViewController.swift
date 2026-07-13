import AppKit

final class SeedFinderViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onUseSeed: ((Int64) -> Void)?

    private let settings: WorldSettings
    private let initialX: Int32
    private let initialZ: Int32
    private let viewModel: SeedFinderViewModel

    private let targetPopup = NSPopUpButton()
    private let xField: NSTextField
    private let zField: NSTextField
    private let startSeedField = NSTextField(string: "0")
    private let endSeedField = NSTextField(string: "1000")
    private let resultLimitPopup = NSPopUpButton()
    private let progressIndicator = NSProgressIndicator()
    private let statusLabel = NSTextField(wrappingLabelWithString: "Ready to search.")
    private let tableView = NSTableView()
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private let useSeedButton = NSButton(title: "Use Seed", target: nil, action: nil)
    private let searchButton = NSButton(title: "Search", target: nil, action: nil)

    private var biomeOptions: [SeedFinderBiomeOption] = []
    private var results: [SeedFinderResult] = []
    private var isSearching = false

    init(
        settings: WorldSettings,
        x: Int32,
        z: Int32,
        finder: any SeedFinding = CubiomesSeedFinder()
    ) {
        self.settings = settings
        self.initialX = x
        self.initialZ = z
        self.xField = NSTextField(string: "\(x)")
        self.zField = NSTextField(string: "\(z)")
        self.viewModel = SeedFinderViewModel(finder: finder)
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 640, height: 590)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureControls()
        buildLayout()
        configureBindings()
    }

    private func configureControls() {
        biomeOptions = SeedFinderCatalog.biomes(for: settings.version, dimension: settings.dimension)
        targetPopup.addItems(withTitles: biomeOptions.map(\.title))

        let currentRequest = BiomeQueryRequest(settings: settings, x: initialX, z: initialZ)
        if
            let currentBiomeID = try? CubiomesBiomeService().biome(for: currentRequest).id,
            let currentIndex = biomeOptions.firstIndex(where: { $0.id == currentBiomeID })
        {
            targetPopup.selectItem(at: currentIndex)
        }

        resultLimitPopup.addItems(withTitles: ["1", "5", "10", "25"])
        resultLimitPopup.selectItem(at: 0)

        [targetPopup, xField, zField, startSeedField, endSeedField, resultLimitPopup].forEach {
            $0.controlSize = .regular
        }
        [xField, zField, startSeedField, endSeedField].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        }

        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        progressIndicator.controlSize = .small

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)

        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearResults)
        clearButton.isEnabled = false

        closeButton.bezelStyle = .rounded
        closeButton.target = self
        closeButton.action = #selector(closeSheet)
        closeButton.keyEquivalent = "\u{1b}"

        useSeedButton.bezelStyle = .rounded
        useSeedButton.target = self
        useSeedButton.action = #selector(useSelectedSeed)
        useSeedButton.isEnabled = false

        searchButton.bezelStyle = .rounded
        searchButton.keyEquivalent = "\r"
        searchButton.target = self
        searchButton.action = #selector(searchOrStop)

        targetPopup.setAccessibilityIdentifier("seedFinder.biome")
        xField.setAccessibilityIdentifier("seedFinder.x")
        zField.setAccessibilityIdentifier("seedFinder.z")
        startSeedField.setAccessibilityIdentifier("seedFinder.startSeed")
        endSeedField.setAccessibilityIdentifier("seedFinder.endSeed")
        resultLimitPopup.setAccessibilityIdentifier("seedFinder.resultLimit")
        progressIndicator.setAccessibilityIdentifier("seedFinder.progress")
        statusLabel.setAccessibilityIdentifier("seedFinder.status")
        clearButton.setAccessibilityIdentifier("seedFinder.clear")
        closeButton.setAccessibilityIdentifier("seedFinder.close")
        useSeedButton.setAccessibilityIdentifier("seedFinder.useSeed")
        searchButton.setAccessibilityIdentifier("seedFinder.search")

        configureTable()
    }

    private func configureTable() {
        let columns: [(String, String, CGFloat)] = [
            ("seed", "Seed", 220),
            ("top16", "Top 16", 100),
            ("lower48", "Lower 48 bit", 180)
        ]
        columns.forEach { identifier, title, width in
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.minWidth = 80
            tableView.addTableColumn(column)
        }
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = NSTableHeaderView()
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.allowsEmptySelection = true
        tableView.rowSizeStyle = .medium
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.frame = NSRect(x: 0, y: 0, width: 568, height: 190)
        tableView.autoresizingMask = [.width]
        tableView.target = self
        tableView.doubleAction = #selector(useSelectedSeed)
        tableView.setAccessibilityIdentifier("seedFinder.results")
    }

    private func configureBindings() {
        viewModel.onChange = { [weak self] model in
            self?.update(state: model.state)
        }
    }

    private func buildLayout() {
        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .width
        content.spacing = 18
        content.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 20, right: 24)
        content.translatesAutoresizingMaskIntoConstraints = false

        content.addArrangedSubview(headerView())
        content.addArrangedSubview(conditionForm())
        content.addArrangedSubview(progressView())
        content.addArrangedSubview(resultsView())
        content.addArrangedSubview(buttonRow())

        view.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            content.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            content.topAnchor.constraint(equalTo: view.topAnchor),
            content.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func headerView() -> NSView {
        let image = NSImageView(image: NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: nil) ?? NSImage())
        image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 24, weight: .medium)
        image.contentTintColor = .controlAccentColor

        let title = NSTextField(labelWithString: "Find Seeds")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: "Find seeds where a target biome appears at one coordinate.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3

        let row = NSStackView(views: [image, labels])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func conditionForm() -> NSView {
        let worldValue = NSTextField(labelWithString: "Minecraft \(settings.version.label) · \(settings.dimension.rawValue)")
        worldValue.textColor = .secondaryLabelColor

        let coordinates = NSStackView(views: [labeledInlineField("X", xField), labeledInlineField("Z", zField)])
        coordinates.orientation = .horizontal
        coordinates.alignment = .centerY
        coordinates.spacing = 12
        coordinates.distribution = .fillEqually

        let range = NSStackView(views: [labeledInlineField("Start", startSeedField), labeledInlineField("End", endSeedField)])
        range.orientation = .horizontal
        range.alignment = .centerY
        range.spacing = 12
        range.distribution = .fillEqually

        let grid = NSGridView(views: [
            [formLabel("World"), worldValue],
            [formLabel("Target biome"), targetPopup],
            [formLabel("Coordinate"), coordinates],
            [formLabel("Seed range"), range],
            [formLabel("Maximum results"), resultLimitPopup]
        ])
        grid.rowSpacing = 10
        grid.columnSpacing = 14
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill

        let help = NSTextField(wrappingLabelWithString: "Seeds are checked in numeric order. This local version searches up to \(SeedFinderRequest.maximumSeedCount.formatted()) seeds at a time.")
        help.font = .systemFont(ofSize: 11)
        help.textColor = .tertiaryLabelColor

        let stack = NSStackView(views: [grid, help])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        return stack
    }

    private func progressView() -> NSView {
        let stack = NSStackView(views: [progressIndicator, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        progressIndicator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func resultsView() -> NSView {
        let title = NSTextField(labelWithString: "Results")
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView

        let stack = NSStackView(views: [title, scrollView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal)
        scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 520).isActive = true
        scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 190).isActive = true
        return stack
    }

    private func buttonRow() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [clearButton, spacer, closeButton, useSeedButton, searchButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func formLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func labeledInlineField(_ title: String, _ field: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        label.widthAnchor.constraint(equalToConstant: 32).isActive = true
        return row
    }

    @objc private func searchOrStop() {
        if isSearching {
            viewModel.cancel()
            searchButton.isEnabled = false
            statusLabel.stringValue = "Stopping search…"
            return
        }

        do {
            let request = try makeRequest()
            results = []
            tableView.reloadData()
            tableView.deselectAll(nil)
            viewModel.start(request)
        } catch let error as BiomeQueryViewModel.QueryError {
            showError(error.message)
        } catch let error as SeedFinderError {
            showError(error.message)
        } catch {
            showError("Enter whole-number seeds, coordinates, and result count.")
        }
    }

    private func makeRequest() throws -> SeedFinderRequest {
        guard biomeOptions.indices.contains(targetPopup.indexOfSelectedItem) else {
            throw SeedFinderError.invalidMaximumResults
        }
        guard let resultLimit = Int(resultLimitPopup.titleOfSelectedItem ?? "") else {
            throw SeedFinderError.invalidMaximumResults
        }
        let startSeed = try BiomeQueryValidation.parseSeed(startSeedField.stringValue)
        let endSeed = try BiomeQueryValidation.parseSeed(endSeedField.stringValue)
        let x = try BiomeQueryValidation.parseCoordinate(xField.stringValue)
        let z = try BiomeQueryValidation.parseCoordinate(zField.stringValue)

        return SeedFinderRequest(
            settings: settings,
            startSeed: startSeed,
            endSeed: endSeed,
            x: x,
            z: z,
            targetBiome: biomeOptions[targetPopup.indexOfSelectedItem],
            maximumResults: resultLimit
        )
    }

    private func update(state: SeedFinderViewModel.State) {
        switch state {
        case .idle:
            setSearching(false)
        case .searching(let progress):
            setSearching(true)
            progressIndicator.doubleValue = progress.fractionCompleted
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = "Checked \(progress.checkedSeeds.formatted()) of \(progress.totalSeeds.formatted()) · Current seed \(progress.currentSeed)"
        case .finished(let found):
            results = found
            tableView.reloadData()
            setSearching(false)
            if found.isEmpty {
                progressIndicator.doubleValue = 1
                statusLabel.stringValue = "No matching seeds found in this range."
            } else {
                statusLabel.stringValue = "Found \(found.count.formatted()) matching seed\(found.count == 1 ? "" : "s")."
                tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
                tableView.scrollRowToVisible(0)
            }
            updateSelectionState()
        case .cancelled(let found):
            results = found
            tableView.reloadData()
            setSearching(false)
            statusLabel.stringValue = "Search stopped."
            updateSelectionState()
        case .failed(let message):
            setSearching(false)
            showError(message)
        }
    }

    private func setSearching(_ searching: Bool) {
        isSearching = searching
        searchButton.title = searching ? "Stop" : "Search"
        searchButton.isEnabled = true
        [targetPopup, xField, zField, startSeedField, endSeedField, resultLimitPopup].forEach {
            $0.isEnabled = !searching
        }
        clearButton.isEnabled = !searching && !results.isEmpty
        updateSelectionState()
    }

    private func showError(_ message: String) {
        statusLabel.textColor = .systemRed
        statusLabel.stringValue = message
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        results.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard results.indices.contains(row), let tableColumn else {
            return nil
        }
        let result = results[row]
        let value: String
        switch tableColumn.identifier.rawValue {
        case "top16":
            value = result.top16Hex
        case "lower48":
            value = result.lower48Hex
        default:
            value = "\(result.seed)"
        }

        let label = NSTextField(labelWithString: value)
        label.font = .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
        label.lineBreakMode = .byTruncatingMiddle
        label.alignment = tableColumn.identifier.rawValue == "seed" ? .right : .left
        label.setAccessibilityLabel(value)
        return label
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateSelectionState()
    }

    private func updateSelectionState() {
        let canUseSeed = !isSearching && results.indices.contains(tableView.selectedRow)
        useSeedButton.isEnabled = canUseSeed
        useSeedButton.keyEquivalent = canUseSeed ? "\r" : ""
        searchButton.keyEquivalent = canUseSeed || isSearching ? "" : "\r"
    }

    @objc private func clearResults() {
        results = []
        tableView.deselectAll(nil)
        tableView.reloadData()
        progressIndicator.doubleValue = 0
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Ready to search."
        setSearching(false)
    }

    @objc private func useSelectedSeed() {
        guard results.indices.contains(tableView.selectedRow) else {
            return
        }
        onUseSeed?(results[tableView.selectedRow].seed)
        dismissSheet()
    }

    @objc private func closeSheet() {
        viewModel.cancel()
        dismissSheet()
    }

    private func dismissSheet() {
        presentingViewController?.dismiss(self)
    }
}
