import AppKit

final class SeedFinderViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onUseWorld: ((WorldSettings) -> Void)?

    private let initialSettings: WorldSettings
    private let initialX: Int32
    private let initialZ: Int32
    private let viewModel: SeedFinderViewModel

    private let versionPopup = NSPopUpButton()
    private let dimensionPopup = NSPopUpButton()
    private let addBiomeButton = NSButton(title: "Add Biome", target: nil, action: nil)
    private let addStructureButton = NSButton(title: "Add Structure", target: nil, action: nil)
    private let conditionStack = NSStackView()
    private let emptyConditionsLabel = NSTextField(wrappingLabelWithString: "Add a biome or structure condition to begin.")

    private let startSeedField = NSTextField(string: "0")
    private let endSeedField = NSTextField(string: "1000")
    private let resultLimitPopup = NSPopUpButton()
    private let progressIndicator = NSProgressIndicator()
    private let statusLabel = NSTextField(wrappingLabelWithString: "Ready to search.")
    private let tableView = NSTableView()
    private let clearButton = NSButton(title: "Clear Results", target: nil, action: nil)
    private let closeButton = NSButton(title: "Close", target: nil, action: nil)
    private let useSeedButton = NSButton(title: "Use This Seed", target: nil, action: nil)
    private let searchButton = NSButton(title: "Start Search", target: nil, action: nil)

    private var conditionRows: [SeedFinderConditionRowView] = []
    private var results: [SeedFinderResult] = []
    private var resultConditionCount = 0
    private var isSearching = false

    init(
        settings: WorldSettings,
        x: Int32,
        z: Int32,
        finder: any SeedFinding = CubiomesSeedFinder()
    ) {
        self.initialSettings = settings
        self.initialX = x
        self.initialZ = z
        self.viewModel = SeedFinderViewModel(finder: finder)
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 720, height: 620)
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
        addInitialBiomeCondition()
    }

    private var selectedVersion: MinecraftVersionOption {
        let index = versionPopup.indexOfSelectedItem
        return MinecraftVersionOption.supported.indices.contains(index)
            ? MinecraftVersionOption.supported[index]
            : initialSettings.version
    }

    private var selectedDimension: DimensionOption {
        let index = dimensionPopup.indexOfSelectedItem
        return DimensionOption.allCases.indices.contains(index)
            ? DimensionOption.allCases[index]
            : initialSettings.dimension
    }

    private func configureControls() {
        versionPopup.addItems(withTitles: MinecraftVersionOption.supported.map(\.label))
        if let index = MinecraftVersionOption.supported.firstIndex(of: initialSettings.version) {
            versionPopup.selectItem(at: index)
        }
        dimensionPopup.addItems(withTitles: DimensionOption.allCases.map(\.rawValue))
        if let index = DimensionOption.allCases.firstIndex(of: initialSettings.dimension) {
            dimensionPopup.selectItem(at: index)
        }
        versionPopup.target = self
        versionPopup.action = #selector(worldSelectionChanged)
        dimensionPopup.target = self
        dimensionPopup.action = #selector(worldSelectionChanged)

        addBiomeButton.image = NSImage(systemSymbolName: "leaf", accessibilityDescription: nil)
        addBiomeButton.imagePosition = .imageLeading
        addBiomeButton.target = self
        addBiomeButton.action = #selector(addBiomeCondition)
        addStructureButton.image = NSImage(systemSymbolName: "building.2", accessibilityDescription: nil)
        addStructureButton.imagePosition = .imageLeading
        addStructureButton.target = self
        addStructureButton.action = #selector(addStructureCondition)

        conditionStack.orientation = .vertical
        conditionStack.alignment = .width
        conditionStack.spacing = 8
        conditionStack.edgeInsets = NSEdgeInsets(top: 0, left: 0, bottom: 6, right: 0)
        conditionStack.setContentHuggingPriority(.required, for: .vertical)
        emptyConditionsLabel.alignment = .center
        emptyConditionsLabel.textColor = .secondaryLabelColor
        emptyConditionsLabel.font = .systemFont(ofSize: 12)

        resultLimitPopup.addItems(withTitles: ["1", "5", "10", "25"])
        resultLimitPopup.selectItem(at: 0)

        [versionPopup, dimensionPopup, startSeedField, endSeedField, resultLimitPopup].forEach {
            $0.controlSize = .regular
        }
        [startSeedField, endSeedField].forEach {
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

        versionPopup.setAccessibilityIdentifier("seedFinder.version")
        dimensionPopup.setAccessibilityIdentifier("seedFinder.dimension")
        addBiomeButton.setAccessibilityIdentifier("seedFinder.addBiome")
        addStructureButton.setAccessibilityIdentifier("seedFinder.addStructure")
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
            ("seed", "Seed", 260),
            ("match", "Matched", 350)
        ]
        columns.forEach { identifier, title, width in
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.minWidth = 120
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
        tableView.frame = NSRect(x: 0, y: 0, width: 640, height: 88)
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
        content.spacing = 10
        content.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 16, right: 20)
        content.translatesAutoresizingMaskIntoConstraints = false

        content.addArrangedSubview(headerView())
        content.addArrangedSubview(worldView())
        content.addArrangedSubview(conditionsView())
        content.addArrangedSubview(searchOptionsView())
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
        image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        image.contentTintColor = .controlAccentColor

        let title = NSTextField(labelWithString: "Find Matching Seeds")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "A seed must satisfy every condition below.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3

        let row = NSStackView(views: [image, labels])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func worldView() -> NSView {
        let title = sectionTitle("Search settings")
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let controls = NSStackView(views: [
            inlineLabeledControl("Version", versionPopup),
            inlineLabeledControl("Dimension", dimensionPopup)
        ])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 16

        let row = NSStackView(views: [title, spacer, controls])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func conditionsView() -> NSView {
        let title = sectionTitle("Required conditions")
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let actions = NSStackView(views: [spacer, addBiomeButton, addStructureButton])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 8

        let heading = NSStackView(views: [title, actions])
        heading.orientation = .horizontal
        heading.alignment = .centerY
        heading.spacing = 12

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        conditionStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = conditionStack
        NSLayoutConstraint.activate([
            conditionStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            conditionStack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            conditionStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            conditionStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 176)
        ])

        let stack = NSStackView(views: [heading, scrollView])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 8
        return stack
    }

    private func searchOptionsView() -> NSView {
        let title = sectionTitle("Seed range")
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let range = NSStackView(views: [
            inlineLabeledControl("From", startSeedField),
            inlineLabeledControl("to", endSeedField),
            inlineLabeledControl("Find up to", resultLimitPopup, suffix: "results")
        ])
        range.orientation = .horizontal
        range.alignment = .centerY
        range.spacing = 12
        startSeedField.widthAnchor.constraint(equalToConstant: 104).isActive = true
        endSeedField.widthAnchor.constraint(equalToConstant: 104).isActive = true
        startSeedField.toolTip = "First seed to check (included)"
        endSeedField.toolTip = "Last seed to check (included)"

        let row = NSStackView(views: [title, spacer, range])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        row.toolTip = "Seeds are checked in order. A search can check up to \(SeedFinderRequest.maximumSeedCount.formatted()) seeds."
        return row
    }

    private func progressView() -> NSView {
        let stack = NSStackView(views: [progressIndicator, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        progressIndicator.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func resultsView() -> NSView {
        let title = sectionTitle("Matching Seeds")
        let hint = NSTextField(labelWithString: "Double-click a seed, or select it and choose Use Seed.")
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let heading = NSStackView(views: [title, spacer, hint])
        heading.orientation = .horizontal
        heading.alignment = .centerY

        let scrollView = NSScrollView()
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = tableView

        let stack = NSStackView(views: [heading, scrollView])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal)
        scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        scrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 600).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 88).isActive = true
        return stack
    }

    private func buttonRow() -> NSView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        useSeedButton.title = "Use Seed"
        let row = NSStackView(views: [clearButton, spacer, closeButton, useSeedButton, searchButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    private func sectionTitle(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func inlineLabeledControl(_ title: String, _ control: NSView, suffix: String? = nil) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        var views: [NSView] = [label, control]
        if let suffix {
            let suffixLabel = NSTextField(labelWithString: suffix)
            suffixLabel.font = .systemFont(ofSize: 11)
            suffixLabel.textColor = .secondaryLabelColor
            views.append(suffixLabel)
        }
        let stack = NSStackView(views: views)
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 7
        return stack
    }

    private func addInitialBiomeCondition() {
        let selectedSettings = WorldSettings(
            seed: initialSettings.seed,
            version: selectedVersion,
            dimension: selectedDimension
        )
        let currentBiomeID = try? CubiomesBiomeService().biome(for: BiomeQueryRequest(
            settings: selectedSettings,
            x: initialX,
            z: initialZ
        )).id
        appendCondition(kind: .biome, preferredBiomeID: currentBiomeID)
    }

    private func appendCondition(
        kind: SeedFinderConditionRowView.Kind,
        preferredBiomeID: Int32? = nil
    ) {
        let row = SeedFinderConditionRowView(
            kind: kind,
            version: selectedVersion,
            dimension: selectedDimension,
            x: initialX,
            z: initialZ,
            preferredBiomeID: preferredBiomeID
        )
        row.onRemove = { [weak self, weak row] in
            guard let self, let row else { return }
            removeCondition(row)
        }
        conditionRows.append(row)
        conditionStack.addArrangedSubview(row)
        updateEmptyConditionsState()
    }

    private func removeCondition(_ row: SeedFinderConditionRowView) {
        guard !isSearching, let index = conditionRows.firstIndex(where: { $0 === row }) else { return }
        conditionRows.remove(at: index)
        conditionStack.removeArrangedSubview(row)
        row.removeFromSuperview()
        updateEmptyConditionsState()
        clearResults()
    }

    private func updateEmptyConditionsState() {
        if conditionRows.isEmpty {
            if emptyConditionsLabel.superview == nil {
                conditionStack.addArrangedSubview(emptyConditionsLabel)
                emptyConditionsLabel.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true
            }
        } else if emptyConditionsLabel.superview != nil {
            conditionStack.removeArrangedSubview(emptyConditionsLabel)
            emptyConditionsLabel.removeFromSuperview()
        }
    }

    @objc private func addBiomeCondition() {
        appendCondition(kind: .biome)
    }

    @objc private func addStructureCondition() {
        appendCondition(kind: .structure)
    }

    @objc private func worldSelectionChanged() {
        conditionRows.forEach {
            $0.updateCatalog(version: selectedVersion, dimension: selectedDimension)
        }
        clearResults()
    }

    @objc private func searchOrStop() {
        if isSearching {
            viewModel.cancel()
            searchButton.isEnabled = false
            statusLabel.stringValue = "Stopping the search…"
            return
        }

        do {
            let request = try makeRequest()
            results = []
            resultConditionCount = request.conditions.count
            tableView.reloadData()
            tableView.deselectAll(nil)
            viewModel.start(request)
        } catch let error as BiomeQueryViewModel.QueryError {
            showError(error.message)
        } catch let error as SeedFinderError {
            showError(error.message)
        } catch {
            showError("Check the seed range and all condition values, then try again.")
        }
    }

    private func makeRequest() throws -> SeedFinderRequest {
        guard let resultLimit = Int(resultLimitPopup.titleOfSelectedItem ?? "") else {
            throw SeedFinderError.invalidMaximumResults
        }
        let startSeed = try BiomeQueryValidation.parseSeed(startSeedField.stringValue)
        let endSeed = try BiomeQueryValidation.parseSeed(endSeedField.stringValue)
        let conditions = try conditionRows.map { try $0.makeCondition() }
        let settings = WorldSettings(seed: initialSettings.seed, version: selectedVersion, dimension: selectedDimension)

        return SeedFinderRequest(
            settings: settings,
            startSeed: startSeed,
            endSeed: endSeed,
            conditions: conditions,
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
            statusLabel.stringValue = "Checked \(progress.checkedSeeds.formatted()) of \(progress.totalSeeds.formatted()) seeds · Now checking \(progress.currentSeed)"
        case .finished(let found):
            results = found
            tableView.reloadData()
            setSearching(false)
            if found.isEmpty {
                progressIndicator.doubleValue = 1
                statusLabel.stringValue = "No seeds in this range matched every condition."
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
            statusLabel.stringValue = "Search stopped. \(found.count.formatted()) result\(found.count == 1 ? "" : "s") kept."
            updateSelectionState()
        case .failed(let message):
            setSearching(false)
            showError(message)
        }
    }

    private func setSearching(_ searching: Bool) {
        isSearching = searching
        searchButton.title = searching ? "Stop Search" : "Start Search"
        searchButton.isEnabled = true
        [versionPopup, dimensionPopup, startSeedField, endSeedField, resultLimitPopup, addBiomeButton, addStructureButton].forEach {
            $0.isEnabled = !searching
        }
        conditionRows.forEach { $0.setEditingEnabled(!searching) }
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
        guard results.indices.contains(row), let tableColumn else { return nil }
        let value = tableColumn.identifier.rawValue == "seed"
            ? "\(results[row].seed)"
            : "All \(resultConditionCount) condition\(resultConditionCount == 1 ? "" : "s")"
        let label = NSTextField(labelWithString: value)
        label.font = tableColumn.identifier.rawValue == "seed"
            ? .monospacedDigitSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular)
            : .systemFont(ofSize: NSFont.smallSystemFontSize)
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
        resultConditionCount = 0
        tableView.deselectAll(nil)
        tableView.reloadData()
        progressIndicator.doubleValue = 0
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = "Ready to search."
        setSearching(false)
    }

    @objc private func useSelectedSeed() {
        guard results.indices.contains(tableView.selectedRow) else { return }
        let settings = WorldSettings(
            seed: results[tableView.selectedRow].seed,
            version: selectedVersion,
            dimension: selectedDimension
        )
        onUseWorld?(settings)
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
