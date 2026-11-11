import UIKit

/// 全局轻量 Toast(显示在 keyWindow 顶部,1.7 秒自动消失)
func showToast(_ message: String) {
    DispatchQueue.main.async {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
        guard let window = window else { return }

        let label = UILabel()
        label.text = message
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .white
        label.backgroundColor = UIColor(white: 0, alpha: 0.78)
        label.textAlignment = .center
        label.numberOfLines = 2
        label.layer.cornerRadius = 12
        label.clipsToBounds = true

        let textSize = (message as NSString).size(
            withAttributes: [.font: label.font]
        )
        let width = min(window.bounds.width - 56, max(150, textSize.width + 44))
        let height = max(38, ceil(textSize.height) + 20)
        label.frame = CGRect(
            x: (window.bounds.width - width) / 2,
            y: window.safeAreaInsets.top + 64,
            width: width,
            height: height
        )
        label.alpha = 0
        window.addSubview(label)

        UIView.animate(withDuration: 0.22) { label.alpha = 1 }
        UIView.animate(withDuration: 0.3, delay: 1.5, options: [.curveEaseIn]) {
            label.alpha = 0
        } completion: { _ in
            label.removeFromSuperview()
        }
    }
}
