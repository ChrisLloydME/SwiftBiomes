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
    private let queryButton = NSButton(title: "Lookup", target: nil, action: nil)

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
        queryButton.bezelStyle = .rounded
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
        dimensionControl.action = #selector(query)
        overlayCheckbox.target = self
        overlayCheckbox.action = #selector(overlayChanged)
        overlayCheckbox.state = .off
        selectAllStructuresButton.bezelStyle = .rounded
        selectAllStructuresButton.controlSize = .small
        selectAllStructuresButton.font = .systemFont(ofSize: 11)
        selectAllStructuresButton.target = self
        selectAllStructuresButton.action = #selector(selectAllStructures)
        selectNoStructuresButton.bezelStyle = .rounded
        selectNoStructuresButton.controlSize = .small
        selectNoStructuresButton.font = .systemFont(ofSize: 11)
        selectNoStructuresButton.target = self
        selectNoStructuresButton.action = #selector(selectNoStructures)

        for type in StructureOverlayType.allCases {
            let checkbox = NSButton(checkboxWithTitle: type.title, target: self, action: #selector(structureTypesChanged))
            checkbox.state = .off
            checkbox.font = .systemFont(ofSize: 12)
            structureTypeCheckboxes[type] = checkbox
        }
        updateStructureTypeCheckboxesEnabled()
    }

    private func buildLayout() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "World")
        title.font = .systemFont(ofSize: 13, weight: .semibold)

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(fieldGroup(label: "Seed", control: seedField))
        stack.addArrangedSubview(fieldGroup(label: "Version", control: versionPopup))
        stack.addArrangedSubview(fieldGroup(label: "Dimension", control: dimensionControl))

        let coordinateRow = NSStackView(views: [
            fieldGroup(label: "X", control: xField),
            fieldGroup(label: "Z", control: zField)
        ])
        coordinateRow.orientation = .horizontal
        coordinateRow.spacing = 8
        coordinateRow.distribution = .fillEqually
        coordinateRow.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(coordinateRow)

        let overlayTitle = NSTextField(labelWithString: "Overlays")
        overlayTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        stack.addArrangedSubview(overlayTitle)
        stack.addArrangedSubview(overlayCheckbox)
        stack.addArrangedSubview(structureSelectionButtonRow())
        stack.addArrangedSubview(structureTypeGroup())
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
            queryButton.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40),
            seedField.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            versionPopup.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            dimensionControl.widthAnchor.constraint(greaterThanOrEqualToConstant: 160)
        ])
    }

    private func fieldGroup(label: String, control: NSView) -> NSStackView {
        let labelView = NSTextField(labelWithString: label)
        labelView.font = .systemFont(ofSize: 11, weight: .medium)
        labelView.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [labelView, control])
        stack.orientation = .vertical
        stack.alignment = .leading
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
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 4, right: 0)

        for type in StructureOverlayType.allCases {
            if let checkbox = structureTypeCheckboxes[type] {
                stack.addArrangedSubview(checkbox)
            }
        }

        return stack
    }

    private func structureSelectionButtonRow() -> NSStackView {
        let stack = NSStackView(views: [selectAllStructuresButton, selectNoStructuresButton])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
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
        structureTypeCheckboxes.values.forEach { $0.state = state }
        publishSelectedStructureTypes()
    }

    private func publishSelectedStructureTypes() {
        let selected = Set(structureTypeCheckboxes.compactMap { type, checkbox in
            checkbox.state == .on ? type : nil
        })
        onStructureTypesChanged?(selected)
    }

    private func updateStructureTypeCheckboxesEnabled() {
        let enabled = overlayCheckbox.state == .on
        structureTypeCheckboxes.values.forEach { $0.isEnabled = enabled }
        selectAllStructuresButton.isEnabled = enabled
        selectNoStructuresButton.isEnabled = enabled
    }
}
