#if os(iOS)
import StupidAgentCore
import UIKit

@objc(KeyboardViewController)
public final class KeyboardViewController: UIInputViewController {
    private let rootStack = UIStackView()
    private let statusLabel = UILabel()
    private var isArabic = false
    private var isShifted = false
    private var isWorking = false
    private var heightConstraint: NSLayoutConstraint?

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .secondarySystemBackground
        buildKeyboard()
    }

    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        statusLabel.text = "حدد نصاً ثم اختر أداة VOID الذكية"
    }

    private func buildKeyboard() {
        rootStack.arrangedSubviews.forEach {
            rootStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        rootStack.axis = .vertical
        rootStack.spacing = 6
        rootStack.distribution = .fill
        if rootStack.superview == nil {
            rootStack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(rootStack)
            NSLayoutConstraint.activate([
                rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 5),
                rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -5),
                rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 7),
                rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -7)
            ])
        }

        let actions = UIStackView()
        actions.axis = .horizontal
        actions.spacing = 6
        actions.distribution = .fillEqually
        actions.addArrangedSubview(actionButton("تحسين") { [weak self] in
            self?.transformSelection(task: "Improve the selected text. Preserve its meaning and language. Return only the improved text.")
        })
        actions.addArrangedSubview(actionButton("اختصار") { [weak self] in
            self?.transformSelection(task: "Make the selected text shorter and clearer. Preserve all important meaning. Return only the revised text.")
        })
        actions.addArrangedSubview(actionButton("ترجمة") { [weak self] in
            self?.translateSelection()
        })
        actions.heightAnchor.constraint(equalToConstant: 38).isActive = true
        rootStack.addArrangedSubview(actions)

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 1
        rootStack.addArrangedSubview(statusLabel)
        statusLabel.heightAnchor.constraint(equalToConstant: 20).isActive = true

        if isArabic {
            addKeyRow(["ض", "ص", "ث", "ق", "ف", "غ", "ع", "ه", "خ", "ح"])
            addKeyRow(["ج", "د", "ش", "س", "ي", "ب", "ل", "ا", "ت", "ن", "م"])
            addKeyRow(["ز", "ظ", "ذ", "ر", "ؤ", "ء", "ئ", "ى", "ة", "و", "⌫"])
        } else {
            addKeyRow(["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"])
            addKeyRow(["a", "s", "d", "f", "g", "h", "j", "k", "l"])
            addKeyRow(["⇧", "z", "x", "c", "v", "b", "n", "m", "⌫"])
        }

        let bottom = UIStackView()
        bottom.axis = .horizontal
        bottom.spacing = 6
        bottom.distribution = .fillEqually
        bottom.addArrangedSubview(keyButton("🌐"))
        bottom.addArrangedSubview(keyButton(isArabic ? "EN" : "ع"))
        bottom.addArrangedSubview(keyButton(isArabic ? "مسافة" : "space"))
        bottom.addArrangedSubview(keyButton("↵"))
        bottom.heightAnchor.constraint(equalToConstant: 43).isActive = true
        rootStack.addArrangedSubview(bottom)

        if heightConstraint == nil {
            let constraint = view.heightAnchor.constraint(equalToConstant: 278)
            constraint.priority = .defaultHigh
            constraint.isActive = true
            heightConstraint = constraint
        }
    }

    private func actionButton(_ title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .tertiarySystemFill
        button.layer.cornerRadius = 7
        button.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        return button
    }

    private func addKeyRow(_ titles: [String]) {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 4
        row.distribution = .fillEqually
        for title in titles {
            row.addArrangedSubview(keyButton(title))
        }
        row.heightAnchor.constraint(equalToConstant: 42).isActive = true
        rootStack.addArrangedSubview(row)
    }

    private func keyButton(_ title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.label, for: .normal)
        button.backgroundColor = .tertiarySystemFill
        button.layer.cornerRadius = 7
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        button.addAction(UIAction { [weak self] _ in
            self?.handleKey(title)
        }, for: .touchUpInside)
        return button
    }

    private func handleKey(_ key: String) {
        switch key {
        case "🌐":
            advanceToNextInputMode()
        case "ع", "EN":
            isArabic.toggle()
            isShifted = false
            buildKeyboard()
        case "space", "مسافة":
            textDocumentProxy.insertText(" ")
        case "↵":
            textDocumentProxy.insertText("\n")
        case "⌫":
            textDocumentProxy.deleteBackward()
        case "⇧":
            isShifted.toggle()
            buildKeyboard()
        default:
            let output = isShifted ? key.uppercased() : key
            textDocumentProxy.insertText(output)
            if isShifted {
                isShifted = false
                buildKeyboard()
            }
        }
    }

    private func translateSelection() {
        let target = isArabic ? "English" : "Arabic"
        transformSelection(task: "Translate the selected text into \(target). Preserve its meaning and tone. Return only the translation.")
    }

    private func transformSelection(task: String) {
        guard !isWorking else { return }
        guard #available(iOS 26.0, *) else {
            statusLabel.text = "يتطلب iOS 26 أو أحدث"
            return
        }
        let rawSelected = textDocumentProxy.selectedText ?? ""
        let selected = rawSelected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty else {
            statusLabel.text = "حدد النص أولاً من التطبيق"
            return
        }
        guard selected.count <= 5000 else {
            statusLabel.text = "النص طويل جداً، حدد جزءاً أصغر"
            return
        }

        isWorking = true
        statusLabel.text = "VOID يفكر محلياً…"
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { isWorking = false }
            do {
                let result = try await VOIDLocalModel.generate(
                    prompt: "\(task)\n\nSelected text:\n\(selected)",
                    instructions: "You are VOID Keyboard, a private on-device writing assistant. Return only the requested replacement text. Never add explanations or quotation marks."
                )
                guard textDocumentProxy.selectedText == rawSelected else {
                    statusLabel.text = "تغيّر التحديد، لم أعدّل النص"
                    return
                }
                textDocumentProxy.insertText(result)
                statusLabel.text = "تمت المعالجة على الجهاز"
            } catch {
                statusLabel.text = error.localizedDescription
            }
        }
    }
}
#endif
