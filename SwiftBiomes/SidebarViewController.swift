import AppKit

final class SidebarViewController: NSViewController {
    var onQueryRequested: ((String, String, String, Int, Int) -> Void)?
    var onOverlayChanged: ((Bool) -> Void)?
    var onStructureTypesChanged: ((Set<StructureOverlayType>) -> Void)?

    private var contentContainer: NSView!
    private let seedField = NSTextField(string: "\(WorldSettings.sample.seed)")
    private let xField = NSTextField(string: "0")
    private let zField = NSTextField(string: "0")
    private let versionPopup = NSPopUpButton()
    private let dimensionControl = NSSegmentedControl(labels: DimensionOption.allCases.map(\.rawValue), trackingMode: .selectOne, target: nil, action: nil)
    private let overlayCheckbox = NSButton(checkboxWithTitle: "Structures", target: nil, action: nil)
    private let selectAllStructuresButton = NSButton(title: "All", target: nil, action: nil)
    private let selectNoStructuresButton = NSButton(title: "None", target: nil, action: nil)
    private let structureAvailabilityLabel = NSTextField(labelWithString: "")
    private var structureTypeCheckboxes: [StructureOverlayType: NSButton] = [:]
    private let queryButton = NSButton(title: "Lookup", target: nil, action: nil)

    private var selectedDimension: DimensionOption {
        let index = dimensionControl.selectedSegment
        guard DimensionOption.allCases.indices.contains(index) else {
            return .overworld
        }
        return DimensionOption.allCases[index]
    }

    override func loadView() {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = contentView

        view = scrollView
        contentContainer = contentView
        scrollView.setAccessibilityLabel("World controls")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureControls()
        buildLayout()
    }

    func setCoordinate(x: Int32, z: Int32) {
        xField.stringValue = "\(x)"
        zField.stringValue = "\(z)"
    }

    func focusCoordinateFields() {
        view.window?.makeFirstResponder(xField)
    }

    private func configureControls() {
        versionPopup.addItems(withTitles: MinecraftVersionOption.supported.map(\.label))
        if let sampleIndex = MinecraftVersionOption.supported.firstIndex(where: { $0.label == WorldSettings.sample.version.label }) {
            versionPopup.selectItem(at: sampleIndex)
        }

        dimensionControl.selectedSegment = DimensionOption.allCases.firstIndex(of: WorldSettings.sample.dimension) ?? 0
        dimensionControl.segmentStyle = .texturedRounded
        dimensionControl.controlSize = .regular
        queryButton.bezelStyle = .rounded
        queryButton.controlSize = .large
        queryButton.font = .systemFont(ofSize: 13, weight: .semibold)
        queryButton.keyEquivalent = "\r"
        queryButton.target = self
        queryButton.action = #selector(query)

        [seedField, xField, zField].forEach { field in
            field.target = self
            field.action = #selector(query)
            field.lineBreakMode = .byTruncatingTail
        }

        versionPopup.target = self
        versionPopup.action = #selector(query)
        dimensionControl.target = self
        dimensionControl.action = #selector(dimensionChanged)
        overlayCheckbox.target = self
        overlayCheckbox.action = #selector(overlayChanged)
        overlayCheckbox.state = .off
        overlayCheckbox.font = .systemFont(ofSize: 13, weight: .medium)
        overlayCheckbox.setAccessibilityLabel("Show structures")
        selectAllStructuresButton.bezelStyle = .inline
        selectAllStructuresButton.controlSize = .small
        selectAllStructuresButton.font = .systemFont(ofSize: 11, weight: .medium)
        selectAllStructuresButton.target = self
        selectAllStructuresButton.action = #selector(selectAllStructures)
        selectNoStructuresButton.bezelStyle = .inline
        selectNoStructuresButton.controlSize = .small
        selectNoStructuresButton.font = .systemFont(ofSize: 11, weight: .medium)
        selectNoStructuresButton.target = self
        selectNoStructuresButton.action = #selector(selectNoStructures)

        structureAvailabilityLabel.font = .systemFont(ofSize: 11)
        structureAvailabilityLabel.textColor = .secondaryLabelColor
        structureAvailabilityLabel.maximumNumberOfLines = 2
        structureAvailabilityLabel.lineBreakMode = .byWordWrapping

        for type in StructureOverlayType.allCases {
            let checkbox = NSButton(checkboxWithTitle: type.title, target: self, action: #selector(structureTypesChanged))
            checkbox.state = .off
            checkbox.font = .systemFont(ofSize: 12)
            checkbox.controlSize = .small
            checkbox.setAccessibilityIdentifier("structure.\(type.rawValue)")
            structureTypeCheckboxes[type] = checkbox
        }
        updateVisibleStructureTypes()
        updateStructureTypeCheckboxesEnabled()
    }

    private func buildLayout() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 0
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 16, bottom: 18, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        stack.addArrangedSubview(appHeader())
        stack.setCustomSpacing(22, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(sectionHeader("WORLD SETTINGS", symbolName: "globe.americas.fill"))
        stack.setCustomSpacing(10, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(fieldGroup(label: "Seed", control: seedField))
        stack.setCustomSpacing(10, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(fieldGroup(label: "Version", control: versionPopup))
        stack.setCustomSpacing(10, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(fieldGroup(label: "Dimension", control: dimensionControl))
        stack.setCustomSpacing(10, after: stack.arrangedSubviews.last!)

        let coordinateRow = NSStackView(views: [
            fieldGroup(label: "X", control: xField),
            fieldGroup(label: "Z", control: zField)
        ])
        coordinateRow.orientation = .horizontal
        coordinateRow.spacing = 8
        coordinateRow.distribution = .fillEqually
        coordinateRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(coordinateRow)
        stack.setCustomSpacing(20, after: coordinateRow)

        stack.addArrangedSubview(divider())
        stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(sectionHeader("MAP LAYERS", symbolName: "square.3.layers.3d"))
        stack.setCustomSpacing(11, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(structureHeaderRow())
        stack.setCustomSpacing(3, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(structureAvailabilityLabel)
        stack.setCustomSpacing(8, after: structureAvailabilityLabel)
        stack.addArrangedSubview(structureTypeGroup())
        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(divider())
        stack.setCustomSpacing(16, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(queryButton)

        guard let scrollView = view as? NSScrollView else {
            return
        }

        contentContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentContainer.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),
            contentContainer.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            seedField.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            versionPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            dimensionControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            queryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
    }

    private func appHeader() -> NSStackView {
        let icon = NSImageView(image: NSImage(systemSymbolName: "mountain.2.fill", accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        icon.contentTintColor = .controlAccentColor
        icon.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "SwiftBiomes")
        title.font = .systemFont(ofSize: 18, weight: .semibold)
        title.textColor = .labelColor

        let subtitle = NSTextField(labelWithString: "Explore a Minecraft world")
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor

        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 1

        let row = NSStackView(views: [icon, labels])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28)
        ])
        return row
    }

    private func sectionHeader(_ title: String, symbolName: String) -> NSStackView {
        let image = NSImageView(image: NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage())
        image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        image.contentTintColor = .tertiaryLabelColor

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor

        let row = NSStackView(views: [image, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        return row
    }

    private func divider() -> NSBox {
        let divider = NSBox()
        divider.boxType = .separator
        return divider
    }

    private func fieldGroup(label: String, control: NSView) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 11, weight: .medium)
        labelView.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [labelView, control])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(greaterThanOrEqualToConstant: 72).isActive = true
        return stack
    }

    private func structureTypeGroup() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 14, bottom: 2, right: 0)
        stack.detachesHiddenViews = true

        for type in StructureOverlayType.allCases {
            if let checkbox = structureTypeCheckboxes[type] {
                stack.addArrangedSubview(checkbox)
            }
        }

        return stack
    }

    private func structureHeaderRow() -> NSStackView {
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [overlayCheckbox, spacer, selectAllStructuresButton, selectNoStructuresButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }

    @objc private func query() {
        onQueryRequested?(
            seedField.stringValue,
            xField.stringValue,
            zField.stringValue,
            versionPopup.indexOfSelectedItem,
            dimensionControl.selectedSegment
        )
    }

    @objc private func dimensionChanged() {
        updateVisibleStructureTypes()
        query()
        publishSelectedStructureTypes()
    }

    @objc private func overlayChanged() {
        updateStructureTypeCheckboxesEnabled()
        onOverlayChanged?(overlayCheckbox.state == .on)
    }

    @objc private func structureTypesChanged() {
        publishSelectedStructureTypes()
    }

    @objc private func selectAllStructures() {
        setAllStructureTypesSelected(true)
    }

    @objc private func selectNoStructures() {
        setAllStructureTypesSelected(false)
    }

    private func setAllStructureTypesSelected(_ selected: Bool) {
        let state: NSControl.StateValue = selected ? .on : .off
        visibleStructureTypes.forEach { structureTypeCheckboxes[$0]?.state = state }
        publishSelectedStructureTypes()
    }

    private func publishSelectedStructureTypes() {
        let selected = Set(visibleStructureTypes.compactMap { type in
            structureTypeCheckboxes[type]?.state == .on ? type : nil
        })
        onStructureTypesChanged?(selected)
    }

    private var visibleStructureTypes: [StructureOverlayType] {
        StructureOverlayType.available(in: selectedDimension)
    }

    private func updateVisibleStructureTypes() {
        let visible = Set(visibleStructureTypes)
        structureTypeCheckboxes.forEach { type, checkbox in
            checkbox.isHidden = !visible.contains(type)
        }
        let count = visible.count
        structureAvailabilityLabel.stringValue = "\(count) available in \(selectedDimension.rawValue)"
    }

    private func updateStructureTypeCheckboxesEnabled() {
        let enabled = overlayCheckbox.state == .on
        structureTypeCheckboxes.values.forEach { $0.isEnabled = enabled }
        selectAllStructuresButton.isEnabled = enabled
        selectNoStructuresButton.isEnabled = enabled
    }
}
