import AppKit

final class InspectorViewController: NSViewController {
    private let statusLabel = NSTextField(wrappingLabelWithString: "Enter a seed and coordinate, then run Lookup.")
    private let biomeNameLabel = NSTextField(labelWithString: "-")
    private let biomeIDLabel = NSTextField(labelWithString: "-")
    private let coordinateLabel = NSTextField(labelWithString: "-")
    private let settingsLabel = NSTextField(wrappingLabelWithString: "-")
    private let overlayLabel = NSTextField(wrappingLabelWithString: CubiomesStructureOverlayProvider().limitation ?? "")

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildLayout()
        update(state: .empty)
    }

    func update(state: BiomeQueryViewModel.State) {
        switch state {
        case .empty:
            statusLabel.stringValue = "Ready"
            biomeNameLabel.stringValue = "-"
            biomeIDLabel.stringValue = "-"
            coordinateLabel.stringValue = "-"
            settingsLabel.stringValue = "-"
        case .loading(let request):
            statusLabel.stringValue = "Looking up biome..."
            coordinateLabel.stringValue = "X \(request.x), Z \(request.z)"
            settingsLabel.stringValue = "\(request.settings.version.label), \(request.settings.dimension.rawValue), seed \(request.settings.seed)"
        case .result(let result):
            statusLabel.stringValue = "Biome found"
            biomeNameLabel.stringValue = result.title
            biomeIDLabel.stringValue = "\(result.id) / \(result.name)"
            coordinateLabel.stringValue = "X \(result.x), Z \(result.z)"
            settingsLabel.stringValue = "\(result.settings.version.label), \(result.settings.dimension.rawValue), seed \(result.settings.seed)"
        case .failed(let message):
            statusLabel.stringValue = message
            biomeNameLabel.stringValue = "-"
            biomeIDLabel.stringValue = "-"
        }
    }

    private func buildLayout() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let title = NSTextField(labelWithString: "Inspector")
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = .secondaryLabelColor
        biomeNameLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        stack.addArrangedSubview(title)
        stack.addArrangedSubview(statusLabel)
        stack.addArrangedSubview(infoGroup(title: "Biome", value: biomeNameLabel))
        stack.addArrangedSubview(infoGroup(title: "ID / Name", value: biomeIDLabel))
        stack.addArrangedSubview(infoGroup(title: "Coordinate", value: coordinateLabel))
        stack.addArrangedSubview(infoGroup(title: "World", value: settingsLabel))

        let overlayTitle = NSTextField(labelWithString: "Structures")
        overlayTitle.font = .systemFont(ofSize: 13, weight: .semibold)
        overlayLabel.textColor = .secondaryLabelColor
        stack.addArrangedSubview(overlayTitle)
        stack.addArrangedSubview(overlayLabel)

        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: view.bottomAnchor),
            statusLabel.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -32),
            settingsLabel.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -32),
            overlayLabel.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor, constant: -32)
        ])
    }

    private func infoGroup(title: String, value: NSTextField) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor
        value.lineBreakMode = .byTruncatingMiddle

        let stack = NSStackView(views: [label, value])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        return stack
    }
}
