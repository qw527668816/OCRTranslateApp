import Foundation

/// 全局配置常量
///
/// ESign/轻松签等自签工具重签时,如果证书不支持默认的 App Group 或 Bundle ID,
/// 只需要改这一个文件(代码侧)+ 两个 .entitlements 文件(签名侧)。
/// 详见 docs/自用安装指南.md 第 3 步。
enum AppConfig {
    /// App Group 组名:主 App 与录屏扩展通过它共享翻译数据
    /// 改名时必须同步修改 OCRTranslate.entitlements 和 ScreenTranslator.entitlements 里的字符串
    static let appGroupID = "group.com.limaoswag.ocrtranslate"

    /// 主 App Bundle ID(改名需同步 project.yml 中 PRODUCT_BUNDLE_IDENTIFIER)
    static let mainBundleID = "app.artichoke1499.strawberry1148"

    /// 录屏扩展 Bundle ID(必须是主 App Bundle ID 的子前缀)
    static let extensionBundleID = "app.artichoke1499.strawberry1148.ScreenTranslator"

    // MARK: App Group 共享容器中的文件名

    static let translationDataFile = "translation_data.json"
    static let broadcastStatusFile = "broadcast_status.txt"
    static let stopSignalFile = "stop_signal.txt"

    /// 单次翻译的最大分段数,防止 OCR 把整屏碎片文字全塞给 API
    static let maxSegmentsPerRequest = 80
}
