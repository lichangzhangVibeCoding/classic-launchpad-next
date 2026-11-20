import Foundation

/// Flat grid order: same kind of app sits together, and the same vendor sits together inside that kind.
enum AppArrangement {
    enum Kind: Int {
        case chat = 0
        case ai
        case browser
        case office
        case dev
        case video
        case music
        case photo
        case remote
        case network
        case finance
        case learn
        case games
        case shop
        case system
        case other
    }

    struct Key: Comparable {
        var kind: Kind
        var vendorRank: Int
        var vendor: String
        var pin: Int
        var name: String

        static func < (lhs: Key, rhs: Key) -> Bool {
            if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
            if lhs.vendorRank != rhs.vendorRank { return lhs.vendorRank < rhs.vendorRank }
            if lhs.vendor != rhs.vendor { return lhs.vendor < rhs.vendor }
            if lhs.pin != rhs.pin { return lhs.pin < rhs.pin }
            if lhs.name != rhs.name {
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            return false
        }
    }

    static func key(for app: AppInfo) -> Key {
        let kind = kind(id: app.id, name: app.name)
        let vendor = vendor(id: app.id, name: app.name)
        return Key(
            kind: kind,
            vendorRank: vendorRank(kind: kind, vendor: vendor),
            vendor: vendor,
            pin: pins[app.id.lowercased()] ?? 50,
            name: app.name
        )
    }

    static func title(_ kind: Kind) -> String {
        switch kind {
        case .chat: return "聊天"
        case .ai: return "AI"
        case .browser: return "浏览器"
        case .office: return "办公"
        case .dev: return "开发"
        case .video: return "视频"
        case .music: return "音乐"
        case .photo: return "图片"
        case .remote: return "网盘与远程"
        case .network: return "网络"
        case .finance: return "理财"
        case .learn: return "学习"
        case .games: return "游戏"
        case .shop: return "购物"
        case .system: return "系统"
        case .other: return "其他"
        }
    }

    private static let pins: [String: Int] = [
        "com.tencent.xinwechat": 0,
        "com.tencent.qq": 1,
        "com.tencent.weworkmac": 2,
        "com.tencent.meeting": 3,
        "com.apple.mobilesms": 0,
        "com.apple.mail": 1,
        "com.apple.facetime": 2,
        "com.apple.mobilephone": 3,
        "com.apple.addressbook": 4,
        "com.bot.pc.doubao": 0,
        "com.work.pc.doubao": 1,
        "com.trae.app": 2,
        "cn.trae.app": 3,
        "cn.trae.solo.app": 4,
        "cn.qwenwork.desktop.mac": 0,
        "com.accio.desktop": 1,
        "com.dingtalk.real": 2,
        "com.tencent.qclaw": 0,
        "com.tencent.workbuddy.mac": 1,
        "app.clawx.desktop": 0,
        "app.redclaw.desktop": 1,
        "com.apple.iwork.pages": 0,
        "com.apple.iwork.numbers": 1,
        "com.apple.iwork.keynote": 2,
        "com.apple.notes": 3,
        "com.apple.ical": 4,
        "com.apple.reminders": 5,
        "com.apple.freeform": 6,
        "com.apple.stickies": 7,
        "com.apple.textedit": 8,
        "com.apple.journal": 9,
        "com.google.chrome.app.mpnpojknpmmopombnjdcgaaiekajbnjb": 0,
        "com.google.chrome.app.fhihpiojkbmbpdjeoajapmgkhlnakfjf": 1,
        "com.google.chrome.app.kefjledonklijopmnomlcbpllchaibag": 2,
        "com.apple.terminal": 0,
        "com.apple.console": 1,
        "com.apple.scripteditor2": 2,
        "com.apple.automator": 3,
        "com.apple.shortcuts": 4,
        "com.bytedance.douyin.desktop": 0,
        "com.google.chrome.app.hilhojagopnlhlnjkjenfebfjlmafogo": 1,
        "com.bytedance.webcastmate.mac": 2,
        "com.lemon.lvpro": 3,
        "com.bilibili.bilibilipc": 0,
        "tv.danmaku.bilibilihd": 1,
        "com.apple.music": 0,
        "com.apple.podcasts": 1,
        "com.apple.garageband10": 2,
        "com.apple.voicememos": 3,
        "cn.toside.anylisten.desktop": 0,
        "cn.toside.music.desktop": 1,
        "com.apple.photos": 0,
        "com.apple.preview": 1,
        "com.apple.photobooth": 2,
        "com.apple.image_capture": 3,
        "com.apple.dictionary": 0,
        "com.apple.ibooksx": 1,
        "com.apple.news": 2,
        "com.apple.weather": 3,
        "com.apple.maps": 4,
        "com.apple.grapher": 5,
        "com.apple.chess": 0,
        "com.apple.games": 1,
        "com.apple.tv": 0,
        "com.apple.quicktimeplayerx": 1,
        "com.apple.finder": 0,
        "com.apple.systempreferences": 1,
        "com.apple.appstore": 2,
        "com.apple.safari": 0,
        "com.google.chrome": 1
    ]

    private static let kinds: [String: Kind] = [
        "com.tencent.xinwechat": .chat,
        "com.tencent.qq": .chat,
        "com.tencent.weworkmac": .chat,
        "com.tencent.meeting": .chat,
        "5zsl2cju2t.com.dingtalk.mac": .chat,
        "com.bytedance.macos.feishu": .chat,
        "com.taobao.aliwangwang": .chat,
        "ru.keepcoder.telegram": .chat,
        "com.hnc.discord": .chat,
        "com.mulerun.chat.intl": .chat,
        "cn.shandianshuo.desktop": .chat,
        "com.google.chrome.app.fmgjjmmmlfnkbppncabfkddbjimcfncm": .chat,
        "com.apple.mobilesms": .chat,
        "com.apple.mail": .chat,
        "com.apple.facetime": .chat,
        "com.apple.mobilephone": .chat,
        "com.apple.addressbook": .chat,

        "com.openai.codex": .ai,
        "com.anthropic.claudefordesktop": .ai,
        "com.bot.pc.doubao": .ai,
        "com.work.pc.doubao": .ai,
        "com.trae.app": .ai,
        "cn.trae.app": .ai,
        "cn.trae.solo.app": .ai,
        "cn.qwenwork.desktop.mac": .ai,
        "com.accio.desktop": .ai,
        "com.dingtalk.real": .ai,
        "com.baidu.qianfan.desktop": .ai,
        "com.tencent.qclaw": .ai,
        "com.tencent.workbuddy.mac": .ai,
        "com.zhipuai.autoclaw": .ai,
        "app.clawx.desktop": .ai,
        "app.redclaw.desktop": .ai,
        "com.anysphere.sand": .ai,
        "com.todesktop.230313mzl4w4u92": .ai,
        "ai.opencode.desktop": .ai,
        "com.joshua-park.mochi-diffusion": .ai,
        "com.apple.generativeplaygroundapp": .ai,
        "now.typeless.desktop": .ai,
        "com.electron.ollama": .ai,

        "com.apple.safari": .browser,
        "com.google.chrome": .browser,
        "com.quark.desktop": .browser,

        "com.apple.iwork.pages": .office,
        "com.apple.iwork.numbers": .office,
        "com.apple.iwork.keynote": .office,
        "com.apple.notes": .office,
        "com.apple.ical": .office,
        "com.apple.reminders": .office,
        "com.apple.freeform": .office,
        "com.apple.stickies": .office,
        "com.apple.textedit": .office,
        "com.apple.journal": .office,
        "com.kingsoft.wpsoffice.mac": .office,
        "net.xmind.vana.app": .office,
        "com.flowus.app": .office,
        "com.google.chrome.app.mpnpojknpmmopombnjdcgaaiekajbnjb": .office,
        "com.google.chrome.app.fhihpiojkbmbpdjeoajapmgkhlnakfjf": .office,
        "com.google.chrome.app.kefjledonklijopmnomlcbpllchaibag": .office,

        "com.apple.terminal": .dev,
        "com.apple.console": .dev,
        "com.apple.scripteditor2": .dev,
        "com.apple.automator": .dev,
        "com.apple.shortcuts": .dev,
        "com.apple.dt.xcode": .dev,
        "com.github.electron": .dev,
        "com.orcaterm.app": .dev,
        "org.filezilla-project.filezilla": .dev,

        "com.bytedance.douyin.desktop": .video,
        "com.google.chrome.app.hilhojagopnlhlnjkjenfebfjlmafogo": .video,
        "com.bytedance.webcastmate.mac": .video,
        "com.lemon.lvpro": .video,
        "com.bilibili.bilibilipc": .video,
        "tv.danmaku.bilibilihd": .video,
        "com.xingin.discover": .video,
        "com.cntv.cboxmac": .video,
        "com.apple.tv": .video,
        "com.apple.quicktimeplayerx": .video,
        "com.timpler.screenstudio": .video,
        "com.google.chrome.app.agimnkijcaahngcdmfeangaknmldooml": .video,
        "com.google.chrome.app.lodlkdfmihgonocnmddehnfgiljnadcf": .video,
        "com.google.chrome.app.dnlbndmlffofcgegifjidpcolhhgaoki": .video,

        "com.apple.music": .music,
        "com.apple.podcasts": .music,
        "com.apple.garageband10": .music,
        "com.apple.voicememos": .music,
        "com.tencent.qqmusicmac": .music,
        "com.netease.163music": .music,
        "com.soda.music": .music,
        "cn.toside.anylisten.desktop": .music,
        "cn.toside.music.desktop": .music,
        "com.google.chrome.app.onhnlmbaciogomhcannjcfepmoihoeed": .music,

        "com.apple.photos": .photo,
        "com.apple.preview": .photo,
        "com.apple.photobooth": .photo,
        "com.apple.image_capture": .photo,
        "com.apple.screenshot.launcher": .photo,
        "com.google.chrome.app.edfdekhlfgcdfailbgnnlkhafjnoghbe": .photo,
        "com.xiaosaiviewer.xiaosai": .photo,
        "com.tianji.quickcad": .photo,
        "com.mimeo.mimeo": .photo,
        "com.milkbooks.app-cocoa": .photo,

        "com.baidu.baidunetdisk-mac": .remote,
        "com.google.chrome.app.aghbiahbpaijignceidepookljebhfak": .remote,
        "com.ugreen.pro.client": .remote,
        "com.youqu.todesk.mac": .remote,
        "com.oray.sunlogin.macclient": .remote,
        "com.apple.screensharing": .remote,
        "com.apple.screencontinuity": .remote,
        "com.microsoft.rdc.macos": .remote,
        "com.thundersoft.ideashare": .remote,

        "io.github.clash-verge-rev.clash-verge-rev": .network,
        "com.nebula.karing": .network,

        "com.emmac.mac": .finance,
        "com.apple.stocks": .finance,

        "com.apple.dictionary": .learn,
        "com.apple.ibooksx": .learn,
        "com.apple.news": .learn,
        "com.apple.weather": .learn,
        "com.apple.maps": .learn,
        "com.apple.grapher": .learn,
        "com.baidu.translateclient": .learn,
        "com.tencent.edu.ketang": .learn,
        "cn.byteforge.hanlinyue": .learn,

        "com.apple.chess": .games,
        "com.apple.games": .games,

        "cn.samsclub.iphone": .shop,
        "com.ebates.safari": .shop,

        "com.hikvision.sentinels": .system,
        "cn.i4tools.mac": .system,
        "keymanager": .system,
        "cx.c3.theunarchiver": .system
    ]

    private static func kind(id: String, name: String) -> Kind {
        let idl = id.lowercased()
        let name = name.lowercased()
        if let known = kinds[idl] { return known }
        if idl.contains("浏览器") || name.contains("浏览器") { return .browser }
        if let guessed = guess(id: idl, name: name) { return guessed }
        if idl.hasPrefix("com.apple.") { return .system }
        return .other
    }

    private static func guess(id: String, name: String) -> Kind? {
        func hit(_ words: String...) -> Bool {
            words.contains { name.contains($0) || id.contains($0) }
        }
        if hit("开发者工具", "wechatwebdevtools", "filezilla", "orcaterm", "xcode", "vscode") { return .dev }
        if name.contains("浏览器") || name.contains("safari") || name.contains("夸克") || name.contains("firefox")
            || name == "google chrome" || name == "chrome" || id == "com.google.chrome" || id == "com.apple.safari"
            || id.contains("quark") {
            return .browser
        }
        if hit("音乐", "网易云", "汽水", "myfreemp3", "podcast", "播客", "garageband") || name == "music" { return .music }
        if hit("扫描全能王", "看图", "照片", "photobooth") || name == "photos" || name == "preview" || name.contains("预览") {
            return .photo
        }
        if hit("微信", "wechat", "钉钉", "dingtalk", "飞书", "telegram", "discord", "gmail", "facetime", "旺旺", "企业微信", "腾讯会议")
            || name == "lark" || name == "mail" || name.contains("邮件") {
            return .chat
        }
        if hit("chatgpt", "claude", "豆包", "doubao", "千问", "qwen", "千帆", "dumate", "claw", "grok", "trae", "cursor", "opencode", "typeless", "ollama", "文生图", "accio", "wukong", "悟空") {
            return .ai
        }
        if hit("wps", "xmind", "flowus", "keynote", "备忘录", "日历", "幻灯片") || name == "pages" || name == "numbers" {
            return .office
        }
        if hit("抖音", "douyin", "哔哩", "bilibili", "小红书", "youtube", "剪映", "直播伴侣", "truth social", "央视", "screen studio") {
            return .video
        }
        if hit("网盘", "todesk", "向日葵", "sunlogin", "云端硬盘", "screensharing", "ideashare") || name.contains("nas") {
            return .remote
        }
        if hit("clash", "karing", "v2ray", "shadowsocks") { return .network }
        if hit("东方财富", "股票") || name == "stocks" { return .finance }
        if hit("词典", "翻译", "课堂", "天气", "地图", "新闻", "图书", "dictionary") { return .learn }
        if hit("象棋", "chess") { return .games }
        if hit("山姆", "rakuten") { return .shop }
        return nil
    }

    private static func vendor(id: String, name: String) -> String {
        let idl = id.lowercased()
        let name = name.lowercased()
        if name.contains("抖音") || name.contains("豆包") || name.contains("飞书") || name.contains("剪映") || name.contains("汽水") || name == "lark" {
            return "bytedance"
        }
        if name.contains("微信") || name.contains("腾讯") || name == "qq" || name.contains("wechat") { return "tencent" }
        if name.contains("哔哩") || name.contains("bilibili") { return "bilibili" }
        if name.contains("小红书") { return "xiaohongshu" }
        if name.contains("网易") { return "netease" }
        if name.contains("夸克") || name.contains("钉钉") || name.contains("旺旺") || name.contains("千问") || name.contains("悟空")
            || name.contains("wukong") || name.contains("dingtalk") || name.contains("qwen") || name == "quark" || name == "accio" {
            return "alibaba"
        }
        if name.contains("扫描全能王") { return "camscanner" }
        if name == "x" { return "x" }
        if name.contains("truth") { return "truth" }

        let prefixes: [(String, String)] = [
            ("com.tencent.", "tencent"),
            ("com.apple.", "apple"),
            ("com.bytedance.", "bytedance"),
            ("com.bot.pc.doubao", "bytedance"),
            ("com.work.pc.doubao", "bytedance"),
            ("com.lemon.", "bytedance"),
            ("com.soda.", "bytedance"),
            ("trae", "bytedance"),
            ("dingtalk", "alibaba"),
            ("aliwangwang", "alibaba"),
            ("taobao", "alibaba"),
            ("qwen", "alibaba"),
            ("quark", "alibaba"),
            ("accio", "alibaba"),
            ("com.baidu.", "baidu"),
            ("com.google.", "google"),
            ("com.openai.", "openai"),
            ("com.anthropic.", "anthropic"),
            ("com.zhipuai.", "zhipu"),
            ("clawx", "claw"),
            ("redclaw", "claw"),
            ("com.netease.", "netease"),
            ("bilibili", "bilibili"),
            ("danmaku", "bilibili"),
            ("com.xingin.", "xiaohongshu"),
            ("com.microsoft.", "microsoft"),
            ("com.oray.", "oray"),
            ("todesktop", "cursor"),
            ("todesk", "todesk"),
            ("youqu", "todesk"),
            ("ugreen", "ugreen"),
            ("clash", "proxy"),
            ("karing", "proxy"),
            ("com.kingsoft.", "kingsoft"),
            ("telegram", "telegram"),
            ("keepcoder", "telegram"),
            ("discord", "discord"),
            ("opencode", "opencode"),
            ("mochi", "mochi"),
            ("typeless", "typeless"),
            ("mulerun", "mulerun"),
            ("shandianshuo", "shandian"),
            ("xmind", "xmind"),
            ("flowus", "flowus"),
            ("filezilla", "filezilla"),
            ("orcaterm", "orcaterm"),
            ("screenstudio", "screenstudio"),
            ("timpler", "screenstudio"),
            ("emmac", "eastmoney"),
            ("hanlinyue", "hanlin"),
            ("byteforge", "hanlin"),
            ("samsclub", "sams"),
            ("ebates", "rakuten"),
            ("rakuten", "rakuten"),
            ("hikvision", "hikvision"),
            ("keymanager", "keymanager"),
            ("unarchiver", "unarchiver"),
            ("i4tools", "i4tools"),
            ("ideashare", "ideashare"),
            ("thundersoft", "ideashare"),
            ("cntv", "cctv"),
            ("cbox", "cctv"),
            ("xiaosaiviewer", "xiaosai"),
            ("quickcad", "cad"),
            ("tianji", "cad"),
            ("mimeo", "mimeo"),
            ("milkbooks", "milk"),
            ("toside", "toside"),
            ("anysphere", "grok"),
            ("com.github.electron", "tencent")
        ]
        for (prefix, vendor) in prefixes where idl.contains(prefix) {
            return vendor
        }
        let parts = idl.split(separator: ".").map(String.init)
        if parts.count >= 2, !idl.hasPrefix("/") { return parts[0] + "." + parts[1] }
        return "other"
    }

    private static func vendorRank(kind: Kind, vendor: String) -> Int {
        let order: [Kind: [String]] = [
            .chat: ["tencent", "alibaba", "bytedance", "telegram", "discord", "mulerun", "shandian", "google", "apple"],
            .ai: ["openai", "anthropic", "bytedance", "cursor", "opencode", "alibaba", "baidu", "tencent", "zhipu", "claw", "grok", "mochi", "apple", "typeless"],
            .browser: ["apple", "google", "alibaba", "bytedance"],
            .office: ["apple", "kingsoft", "google", "xmind", "flowus"],
            .dev: ["apple", "orcaterm", "tencent", "filezilla"],
            .video: ["bytedance", "bilibili", "xiaohongshu", "cctv", "apple", "google", "x", "truth", "screenstudio"],
            .music: ["apple", "tencent", "netease", "bytedance", "toside", "google"],
            .photo: ["apple", "camscanner", "xiaosai", "cad", "mimeo", "milk"],
            .remote: ["baidu", "google", "ugreen", "todesk", "oray", "apple", "microsoft", "ideashare"],
            .network: ["proxy"],
            .finance: ["eastmoney", "apple"],
            .learn: ["apple", "baidu", "tencent", "hanlin"],
            .games: ["apple"],
            .shop: ["sams", "rakuten"],
            .system: ["apple", "i4tools", "hikvision", "keymanager", "unarchiver"]
        ]
        if let list = order[kind], let index = list.firstIndex(of: vendor) { return index }
        return 80
    }
}
