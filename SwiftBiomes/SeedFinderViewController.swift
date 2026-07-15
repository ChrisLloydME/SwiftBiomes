import AppKit

private final class SeedFinderConditionStackView: NSStackView {
    override var isFlipped: Bool { true }
}

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
    private let conditionStack = SeedFinderConditionStackView()
    private let emptyConditionsLabel = NSTextField(wrappingLabelWithString: "Add a biome or structure to describe the world you want to find.")

    private let startSeedField = NSTextField(string: "0")
    private let endSeedField = NSTextField(string: "1000")
    private let resultLimitPopup = NSPopUpButton()
    private let progressIndicator = NSProgressIndicator()
    private let statusLabel = NSTextField(wrappingLabelWithString: "Ready. Review the conditions, then start the search.")
    private let tableView = NSTableView()
    private let resultsScrollView = NSScrollView()
    private let resultsPlaceholder = NSTextField(wrappingLabelWithString: "No results yet. Start a search to see matching seeds.")
    private let resultsPlaceholderView = NSBox()
    private let clearButton = NSButton(title: "Clear", target: nil, action: nil)
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
        conditionStack.edgeInsets = NSEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
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

        resultsPlaceholder.alignment = .center
        resultsPlaceholder.font = .systemFont(ofSize: 12)
        resultsPlaceholder.textColor = .secondaryLabelColor
        resultsPlaceholderView.boxType = .custom
        resultsPlaceholderView.borderColor = .separatorColor
        resultsPlaceholderView.borderWidth = 1
        resultsPlaceholderView.fillColor = .controlBackgroundColor
        resultsPlaceholderView.cornerRadius = 6
        if let placeholderContent = resultsPlaceholderView.contentView {
            resultsPlaceholder.translatesAutoresizingMaskIntoConstraints = false
            placeholderContent.addSubview(resultsPlaceholder)
            NSLayoutConstraint.activate([
                resultsPlaceholder.leadingAnchor.constraint(equalTo: placeholderContent.leadingAnchor, constant: 12),
                resultsPlaceholder.trailingAnchor.constraint(equalTo: placeholderContent.trailingAnchor, constant: -12),
                resultsPlaceholder.centerYAnchor.constraint(equalTo: placeholderContent.centerYAnchor)
            ])
        }

        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        clearButton.target = self
        clearButton.action = #selector(clearResults)
        clearButton.isEnabled = false
        clearButton.isHidden = true

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
            ("match", "Conditions", 350)
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
        tableView.frame = NSRect(x: 0, y: 0, width: 640, height: 96)
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
        content.spacing = 14
        content.edgeInsets = NSEdgeInsets(top: 20, left: 24, bottom: 18, right: 24)
        content.translatesAutoresizingMaskIntoConstraints = false

        content.addArrangedSubview(headerView())
        content.addArrangedSubview(searchSettingsView())
        content.addArrangedSubview(conditionsView())
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
        let title = NSTextField(labelWithString: "Find Matching Seeds")
        title.font = .systemFont(ofSize: 20, weight: .semibold)
        let subtitle = NSTextField(labelWithString: "Describe the world you want. Every condition must match.")
        subtitle.font = .systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor

        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3
        return labels
    }

    private func searchSettingsView() -> NSView {
        let worldControls = NSStackView(views: [
            inlineLabeledControl("Version", versionPopup),
            inlineLabeledControl("Dimension", dimensionPopup)
        ])
        worldControls.orientation = .horizontal
        worldControls.alignment = .centerY
        worldControls.spacing = 20
        versionPopup.widthAnchor.constraint(equalToConstant: 110).isActive = true
        dimensionPopup.widthAnchor.constraint(equalToConstant: 140).isActive = true

        let rangeControls = NSStackView(views: [
            inlineLabeledControl("From", startSeedField),
            inlineLabeledControl("to", endSeedField),
            inlineLabeledControl("Maximum results", resultLimitPopup)
        ])
        rangeControls.orientation = .horizontal
        rangeControls.alignment = .centerY
        rangeControls.spacing = 14
        startSeedField.widthAnchor.constraint(equalToConstant: 98).isActive = true
        endSeedField.widthAnchor.constraint(equalToConstant: 98).isActive = true
        resultLimitPopup.widthAnchor.constraint(equalToConstant: 76).isActive = true
        startSeedField.toolTip = "First seed to check, included"
        endSeedField.toolTip = "Last seed to check, included"

        let stack = NSStackView(views: [
            formRow(label: "Minecraft", content: worldControls),
            formRow(label: "Seeds to check", content: rangeControls)
        ])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        stack.toolTip = "Seeds are checked in order, including both ends of the range."
        return stack
    }

    private func conditionsView() -> NSView {
        let title = sectionTitle("Conditions")
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
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .controlBackgroundColor
        scrollView.setContentHuggingPriority(.defaultLow, for: .vertical)

        conditionStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = conditionStack
        NSLayoutConstraint.activate([
            conditionStack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            conditionStack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
            conditionStack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            conditionStack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 174)
        ])

        let stack = NSStackView(views: [heading, scrollView])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 10
        stack.setContentHuggingPriority(.defaultLow, for: .vertical)
        return stack
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
        let title = sectionTitle("Results")
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let heading = NSStackView(views: [title, spacer, clearButton])
        heading.orientation = .horizontal
        heading.alignment = .centerY

        resultsScrollView.borderType = .bezelBorder
        resultsScrollView.hasVerticalScroller = true
        resultsScrollView.autohidesScrollers = true
        resultsScrollView.documentView = tableView
        resultsScrollView.isHidden = true

        let stack = NSStackView(views: [heading, resultsPlaceholderView, resultsScrollView])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 7
        stack.setContentHuggingPriority(.fittingSizeCompression, for: .horizontal)
        resultsPlaceholderView.heightAnchor.constraint(equalToConstant: 54).isActive = true
        resultsScrollView.widthAnchor.constraint(greaterThanOrEqualToConstant: 600).isActive = true
        resultsScrollView.heightAnchor.constraint(equalToConstant: 96).isActive = true
        return stack
    }

    private func buttonRow() -> NSView {
        useSeedButton.title = "Use Seed"
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [spacer, closeButton, useSeedButton, searchButton])
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

    private func formRow(label title: String, content: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 92).isActive = true

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [label, content, spacer])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
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
                statusLabel.stringValue = "Found \(found.count.formatted()) matching seed\(found.count == 1 ? "" : "s"). Select one to use it."
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
        clearButton.isHidden = results.isEmpty
        resultsPlaceholderView.isHidden = !results.isEmpty
        resultsScrollView.isHidden = results.isEmpty
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
            : "\(resultConditionCount) of \(resultConditionCount) matched"
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
        statusLabel.stringValue = "Ready. Review the conditions, then start the search."
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
