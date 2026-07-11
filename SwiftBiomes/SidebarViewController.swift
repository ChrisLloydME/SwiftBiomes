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
    private var structureTypeCheckboxes: [StructureOverlayType: NSButton] = [:]
    private var structureTypeRows: [StructureOverlayType: NSView] = [:]
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

        let contentView = FlippedView()
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

        for type in StructureOverlayType.allCases {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(structureTypesChanged))
            checkbox.state = .off
            checkbox.controlSize = .small
            checkbox.setAccessibilityLabel(type.title)
            checkbox.setAccessibilityIdentifier("structure.\(type.rawValue)")
            structureTypeCheckboxes[type] = checkbox
            structureTypeRows[type] = structureRow(for: type, checkbox: checkbox)
        }
        updateVisibleStructureTypes()
        updateStructureTypeCheckboxesEnabled()
    }

    private func buildLayout() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 0
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

        let xCoordinate = inlineField(label: "X", control: xField)
        let zCoordinate = inlineField(label: "Z", control: zField)
        let coordinateRow = NSStackView(views: [xCoordinate, zCoordinate])
        coordinateRow.orientation = .horizontal
        coordinateRow.alignment = .centerY
        coordinateRow.spacing = 12
        coordinateRow.distribution = .fillEqually
        coordinateRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(coordinateRow)
        stack.setCustomSpacing(20, after: coordinateRow)

        stack.addArrangedSubview(divider())
        stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(sectionHeader("MAP LAYERS", symbolName: "square.3.layers.3d"))
        stack.setCustomSpacing(11, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(structureHeaderRow())
        stack.setCustomSpacing(8, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(structureTypeGroup())
        stack.setCustomSpacing(20, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(divider())
        stack.setCustomSpacing(16, after: stack.arrangedSubviews.last!)
        stack.addArrangedSubview(queryButton)

        guard let scrollView = view as? NSScrollView else {
            return
        }

        contentContainer.addSubview(stack)

        for arrangedSubview in stack.arrangedSubviews {
            arrangedSubview.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor, constant: -18),
            contentContainer.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor),
            seedField.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            versionPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            dimensionControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            queryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
    }

    private func appHeader() -> NSView {
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

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            row.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            row.topAnchor.constraint(equalTo: container.topAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }

    private func sectionHeader(_ title: String, symbolName: String) -> NSView {
        let image = NSImageView(image: NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) ?? NSImage())
        image.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
        image.contentTintColor = .tertiaryLabelColor

        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.alignment = .left

        let row = NSStackView(views: [image, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.topAnchor.constraint(equalTo: container.topAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
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
        labelView.alignment = .left

        let stack = NSStackView(views: [labelView, control])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            labelView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            control.widthAnchor.constraint(equalTo: stack.widthAnchor),
            control.widthAnchor.constraint(greaterThanOrEqualToConstant: 72)
        ])
        return stack
    }

    private func inlineField(label: String, control: NSView) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        labelView.textColor = .secondaryLabelColor
        labelView.alignment = .left
        labelView.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [labelView, control])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        labelView.widthAnchor.constraint(equalToConstant: 10).isActive = true
        return stack
    }

    private func structureTypeGroup() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 2
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.detachesHiddenViews = true

        for type in StructureOverlayType.allCases {
            if let row = structureTypeRows[type] {
                stack.addArrangedSubview(row)
            }
        }

        return stack
    }

    private func structureRow(for type: StructureOverlayType, checkbox: NSButton) -> NSView {
        let iconPlate = NSBox()
        iconPlate.boxType = .custom
        iconPlate.borderWidth = 0
        iconPlate.cornerRadius = 6
        iconPlate.fillColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.12)
        iconPlate.translatesAutoresizingMaskIntoConstraints = false

        let fallback = NSImage(systemSymbolName: "questionmark.square.dashed", accessibilityDescription: nil)
        let image = NSImageView(image: structureIcon(for: type) ?? fallback ?? NSImage())
        image.imageScaling = .scaleProportionallyUpOrDown
        image.translatesAutoresizingMaskIntoConstraints = false
        image.wantsLayer = true
        image.layer?.magnificationFilter = .nearest
        image.layer?.minificationFilter = .nearest
        iconPlate.addSubview(image)

        let title = NSTextField(labelWithString: type.title)
        title.font = .systemFont(ofSize: 12)
        title.textColor = .labelColor
        title.lineBreakMode = .byTruncatingTail
        title.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [iconPlate, title, spacer, checkbox])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        row.edgeInsets = NSEdgeInsets(top: 3, left: 5, bottom: 3, right: 3)
        row.translatesAutoresizingMaskIntoConstraints = false
        row.setAccessibilityElement(false)

        NSLayoutConstraint.activate([
            iconPlate.widthAnchor.constraint(equalToConstant: 26),
            iconPlate.heightAnchor.constraint(equalToConstant: 26),
            image.centerXAnchor.constraint(equalTo: iconPlate.centerXAnchor),
            image.centerYAnchor.constraint(equalTo: iconPlate.centerYAnchor),
            image.widthAnchor.constraint(equalToConstant: 20),
            image.heightAnchor.constraint(equalToConstant: 20),
            row.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
        return row
    }

    private func structureIcon(for type: StructureOverlayType) -> NSImage? {
        guard let url = Bundle.main.url(forResource: type.iconResourceName, withExtension: "png") else {
            return nil
        }
        return NSImage(contentsOf: url)
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
        structureTypeRows.forEach { type, row in
            row.isHidden = !visible.contains(type)
        }
    }

    private func updateStructureTypeCheckboxesEnabled() {
        let enabled = overlayCheckbox.state == .on
        structureTypeCheckboxes.values.forEach { $0.isEnabled = enabled }
        selectAllStructuresButton.isEnabled = enabled
        selectNoStructuresButton.isEnabled = enabled
    }
}

private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
