import AppKit

final class SeedFinderConditionRowView: NSBox {
    enum Kind {
        case biome
        case structure
    }

    let kind: Kind
    var onRemove: (() -> Void)?

    private let targetPopup = NSPopUpButton()
    private let xField: NSTextField
    private let zField: NSTextField
    private let radiusField = NSTextField(string: "256")
    private let availabilityLabel = NSTextField(wrappingLabelWithString: "")
    private let removeButton = NSButton()

    private var biomeOptions: [SeedFinderBiomeOption] = []
    private var structureOptions: [SeedFinderStructureOption] = []

    init(
        kind: Kind,
        version: MinecraftVersionOption,
        dimension: DimensionOption,
        x: Int32,
        z: Int32,
        preferredBiomeID: Int32? = nil
    ) {
        self.kind = kind
        self.xField = NSTextField(string: "\(x)")
        self.zField = NSTextField(string: "\(z)")
        super.init(frame: .zero)

        boxType = .primary
        titlePosition = .noTitle
        contentViewMargins = NSSize(width: 12, height: 9)
        setContentHuggingPriority(.required, for: .vertical)
        configureControls()
        buildLayout()
        updateCatalog(version: version, dimension: dimension, preferredBiomeID: preferredBiomeID)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateCatalog(
        version: MinecraftVersionOption,
        dimension: DimensionOption,
        preferredBiomeID: Int32? = nil
    ) {
        switch kind {
        case .biome:
            let previousID = selectedBiome?.id ?? preferredBiomeID
            biomeOptions = SeedFinderCatalog.biomes(for: version, dimension: dimension)
            targetPopup.removeAllItems()
            targetPopup.addItems(withTitles: biomeOptions.map(\.title))
            if let previousID, let index = biomeOptions.firstIndex(where: { $0.id == previousID }) {
                targetPopup.selectItem(at: index)
            }
            availabilityLabel.stringValue = biomeOptions.isEmpty
                ? "No biomes are available for this version and dimension."
                : ""
        case .structure:
            let previousType = selectedStructure?.type
            structureOptions = SeedFinderCatalog.structures(for: version, dimension: dimension)
            targetPopup.removeAllItems()
            targetPopup.addItems(withTitles: structureOptions.map(\.title))
            if let previousType, let index = structureOptions.firstIndex(where: { $0.type == previousType }) {
                targetPopup.selectItem(at: index)
            } else if let villageIndex = structureOptions.firstIndex(where: { $0.type == .village }) {
                targetPopup.selectItem(at: villageIndex)
            }
            availabilityLabel.stringValue = structureOptions.isEmpty
                ? "No structures are available for this version and dimension."
                : ""
        }
        targetPopup.isEnabled = targetPopup.numberOfItems > 0
        availabilityLabel.isHidden = availabilityLabel.stringValue.isEmpty
    }

    func makeCondition() throws -> SeedFinderCondition {
        let x = try BiomeQueryValidation.parseCoordinate(xField.stringValue)
        let z = try BiomeQueryValidation.parseCoordinate(zField.stringValue)

        switch kind {
        case .biome:
            guard let selectedBiome else {
                throw SeedFinderError.unavailableConditionTarget
            }
            return .biome(SeedFinderBiomeCondition(biome: selectedBiome, x: x, z: z))
        case .structure:
            guard let selectedStructure else {
                throw SeedFinderError.unavailableConditionTarget
            }
            guard let radius = Int32(radiusField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw SeedFinderError.invalidStructureRadius
            }
            return .structure(SeedFinderStructureCondition(
                structure: selectedStructure,
                centerX: x,
                centerZ: z,
                radius: radius
            ))
        }
    }

    func setEditingEnabled(_ enabled: Bool) {
        [targetPopup, xField, zField, radiusField, removeButton].forEach { $0.isEnabled = enabled }
    }

    private var selectedBiome: SeedFinderBiomeOption? {
        guard biomeOptions.indices.contains(targetPopup.indexOfSelectedItem) else { return nil }
        return biomeOptions[targetPopup.indexOfSelectedItem]
    }

    private var selectedStructure: SeedFinderStructureOption? {
        guard structureOptions.indices.contains(targetPopup.indexOfSelectedItem) else { return nil }
        return structureOptions[targetPopup.indexOfSelectedItem]
    }

    private func configureControls() {
        [xField, zField, radiusField].forEach {
            $0.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            $0.controlSize = .regular
        }
        targetPopup.controlSize = .regular

        availabilityLabel.font = .systemFont(ofSize: 11)
        availabilityLabel.textColor = .systemRed

        removeButton.image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Remove condition")
        removeButton.bezelStyle = .inline
        removeButton.controlSize = .small
        removeButton.contentTintColor = .secondaryLabelColor
        removeButton.target = self
        removeButton.action = #selector(removeCondition)
        removeButton.toolTip = "Remove this condition"

        switch kind {
        case .biome:
            targetPopup.setAccessibilityIdentifier("seedFinder.condition.biome")
            xField.setAccessibilityIdentifier("seedFinder.condition.biomeX")
            zField.setAccessibilityIdentifier("seedFinder.condition.biomeZ")
        case .structure:
            targetPopup.setAccessibilityIdentifier("seedFinder.condition.structure")
            xField.setAccessibilityIdentifier("seedFinder.condition.structureX")
            zField.setAccessibilityIdentifier("seedFinder.condition.structureZ")
            radiusField.setAccessibilityIdentifier("seedFinder.condition.structureRadius")
        }
        removeButton.setAccessibilityIdentifier("seedFinder.condition.remove")
    }

    private func buildLayout() {
        guard let contentView else { return }

        let title = NSTextField(labelWithString: kind == .biome ? "Biome at coordinates" : "Structure in an area")
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        let explanation = NSTextField(wrappingLabelWithString: kind == .biome
            ? "The biome at this exact X/Z position must match."
            : "At least one valid structure must generate inside the square search area.")
        explanation.font = .systemFont(ofSize: 11)
        explanation.textColor = .secondaryLabelColor

        let headingLabels = NSStackView(views: [title, explanation])
        headingLabels.orientation = .vertical
        headingLabels.alignment = .leading
        headingLabels.spacing = 1

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let heading = NSStackView(views: [headingLabels, spacer, removeButton])
        heading.orientation = .horizontal
        heading.alignment = .top
        heading.spacing = 8

        let position = NSStackView(views: [inlineField(label: "X", field: xField), inlineField(label: "Z", field: zField)])
        position.orientation = .horizontal
        position.alignment = .centerY
        position.distribution = .fillEqually
        position.spacing = 10

        var rows: [[NSView]] = [
            [formLabel(kind == .biome ? "Biome" : "Structure"), targetPopup],
            [formLabel(kind == .biome ? "Coordinates" : "Search center"), position]
        ]
        if kind == .structure {
            let radius = NSStackView(views: [radiusField, NSTextField(labelWithString: "blocks each way")])
            radius.orientation = .horizontal
            radius.alignment = .centerY
            radius.spacing = 8
            radiusField.widthAnchor.constraint(equalToConstant: 110).isActive = true
            rows.append([formLabel("Search range"), radius])
        }

        let grid = NSGridView(views: rows)
        grid.rowSpacing = 6
        grid.columnSpacing = 12
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).xPlacement = .fill

        let stack = NSStackView(views: [heading, grid, availabilityLabel])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 7
        stack.setContentHuggingPriority(.required, for: .vertical)
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            widthAnchor.constraint(greaterThanOrEqualToConstant: 620)
        ])
    }

    private func formLabel(_ title: String) -> NSTextField {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func inlineField(label title: String, field: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        label.textColor = .secondaryLabelColor
        let row = NSStackView(views: [label, field])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        label.widthAnchor.constraint(equalToConstant: 10).isActive = true
        return row
    }

    @objc private func removeCondition() {
        onRemove?()
    }
}
