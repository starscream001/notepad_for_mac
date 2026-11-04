import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import NotepadCore

private struct DonationConfiguration: Decodable {
    let recipient: String?
    let paymentURL: String?
    let phone: String?
    let bank: String?
    var url: URL? {
        guard let paymentURL, let url = URL(string: paymentURL), url.scheme == "https", url.host != nil,
              url.user == nil, url.password == nil else { return nil }
        return url
    }
}

private final class QRCodeView: NSView {
    let code: CGImage
    init(code: CGImage) { self.code = code; super.init(frame: .zero); setAccessibilityLabel(L("QR-код для поддержки разработчика через банк")) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill()
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.interpolationQuality = .none
        let side = floor(min(bounds.width, bounds.height) - 32)
        context.draw(code, in: CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side))
    }
}

final class SupportWindow: NSObject {
    static let shared = SupportWindow()
    private var panel: NSPanel?
    private var configuration: DonationConfiguration?
    func invalidateLocalization() { panel?.close(); panel = nil }
    func show() {
        if let panel { panel.makeKeyAndOrderFront(nil); return }
        if let url = Bundle.main.url(forResource: "Donation", withExtension: "json"), let data = try? Data(contentsOf: url) {
            configuration = try? JSONDecoder().decode(DonationConfiguration.self, from: data)
        }
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .centerX; stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 28, bottom: 24, right: 28)
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.widthAnchor.constraint(equalToConstant: 72).isActive = true; icon.heightAnchor.constraint(equalToConstant: 72).isActive = true
        let title = NSTextField(labelWithString: L("Поддержать разработчика")); title.font = .systemFont(ofSize: 19, weight: .semibold)
        let subtitle = NSTextField(wrappingLabelWithString: L("Разработчик — Илья (starscream001).\nNotepad Mac бесплатный и открытый. Поддержка добровольная — все функции доступны каждому."))
        subtitle.alignment = .center; subtitle.widthAnchor.constraint(equalToConstant: 380).isActive = true
        [icon, title, subtitle].forEach(stack.addArrangedSubview)
        if let url = configuration?.url {
            if let recipient = configuration?.recipient, !recipient.isEmpty {
                stack.addArrangedSubview(NSTextField(labelWithString: L("Получатель: \(recipient)")))
            }
            let filter = CIFilter.qrCodeGenerator(); filter.message = Data(url.absoluteString.utf8); filter.correctionLevel = "M"
            if let output = filter.outputImage, let image = CIContext().createCGImage(output, from: output.extent) {
                let qr = QRCodeView(code: image)
                qr.widthAnchor.constraint(equalToConstant: 248).isActive = true; qr.heightAnchor.constraint(equalToConstant: 248).isActive = true
                stack.addArrangedSubview(qr)
            }
            let hint = NSTextField(wrappingLabelWithString: L("Отсканируйте QR телефоном. Сумму и перевод подтвердите в своём банковском приложении."))
            hint.font = .systemFont(ofSize: 12); hint.textColor = .secondaryLabelColor; hint.alignment = .center
            hint.widthAnchor.constraint(equalToConstant: 380).isActive = true; stack.addArrangedSubview(hint)
            let buttons = NSStackView(views: [button(L("Открыть ссылку"), #selector(openPayment)), button(L("Скопировать ссылку"), #selector(copyPayment))]); buttons.spacing = 12
            stack.addArrangedSubview(buttons)
        }
        if let phone = configuration?.phone, !phone.isEmpty, let bank = configuration?.bank, !bank.isEmpty {
            let phoneLabel = NSTextField(labelWithString: L("СБП: \(phone) · \(bank)")); phoneLabel.isSelectable = true
            stack.addArrangedSubview(phoneLabel)
            let hint = NSTextField(wrappingLabelWithString: L("Перевод через СБП по номеру телефона. Выберите Ozon Банк и подтвердите перевод в своём банке."))
            hint.alignment = .center; hint.font = .systemFont(ofSize: 12); hint.textColor = .secondaryLabelColor
            hint.widthAnchor.constraint(equalToConstant: 380).isActive = true
            stack.addArrangedSubview(hint); stack.addArrangedSubview(button(L("Скопировать номер"), #selector(copyPhone)))
        }
        let divider = NSBox(); divider.boxType = .separator; divider.widthAnchor.constraint(equalToConstant: 380).isActive = true
        stack.addArrangedSubview(divider)
        let community = NSTextField(wrappingLabelWithString: L("Можно поддержать проект отзывом, сообщением об ошибке или звездой на GitHub."))
        community.alignment = .center; community.widthAnchor.constraint(equalToConstant: 380).isActive = true
        stack.addArrangedSubview(community)
        stack.addArrangedSubview(button(L("Открыть проект на GitHub"), #selector(openRepository)))
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 436, height: 300), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = L("Поддержка Notepad Mac"); panel.isReleasedWhenClosed = false; panel.contentView = stack
        panel.setContentSize(NSSize(width: 436, height: stack.fittingSize.height))
        self.panel = panel; panel.center(); panel.makeKeyAndOrderFront(nil)
    }
    private func button(_ title: String, _ action: Selector) -> NSButton { let b = NSButton(title: title, target: self, action: action); b.bezelStyle = .rounded; return b }
    @objc private func openRepository() { NSWorkspace.shared.open(UpdatePolicy.repositoryURL) }
    @objc private func openPayment() { if let url = configuration?.url { NSWorkspace.shared.open(url) } }
    @objc private func copyPayment() { if let url = configuration?.url { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url.absoluteString, forType: .string) } }
    @objc private func copyPhone() { if let phone = configuration?.phone { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(phone.filter { $0.isNumber || $0 == "+" }, forType: .string) } }
}
