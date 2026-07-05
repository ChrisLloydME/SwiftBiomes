import AppKit

final class SidebarViewController: NSViewController {
    var onQueryRequested: ((String, String, String, Int, Int) -> Void)?
    var onOverlayChanged: ((Bool) -> Void)?

    private var contentContainer: NSView!
    private let seedField = NSTextField(string: "\(WorldSettings.sample.seed)")
    private let xField = NSTextField(string: "0")
    private let zField = NSTextField(string: "0")
    private let versionPopup = NSPopUpButton()
    private let dimensionControl = NSSegmentedControl(labels: DimensionOption.allCases.map(\.rawValue), trackingMode: .selectOne, target: nil, action: nil)
    private let overlayCheckbox = NSButton(checkboxWithTitle: "Structures", target: nil, action: nil)
    private let queryButton = NSButton(title: "Lookup", target: nil, action: nil)

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer = view
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
        stack.addArrangedSubview(queryButton)

        contentContainer.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentContainer.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: contentContainer.bottomAnchor),
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
        onOverlayChanged?(overlayCheckbox.state == .on)
    }
}
