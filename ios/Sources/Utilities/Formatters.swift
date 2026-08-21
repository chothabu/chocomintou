import Foundation

enum Formatters {
    /// 「10分前」「3日前」。目撃情報とレビューの時刻表示に使う。
    static func relative(_ date: Date, now: Date = .now) -> String {
        let elapsed = now.timeIntervalSince(date)
        if elapsed < 60 { return "たった今" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: now)
    }

    /// 「2026年8月20日」
    static func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar.japanese
        formatter.timeZone = Calendar.japanese.timeZone
        formatter.dateFormat = "yyyy年M月d日"
        return formatter.string(from: date)
    }

    /// 「8月20日」
    static func monthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar.japanese
        formatter.timeZone = Calendar.japanese.timeZone
        formatter.dateFormat = "M月d日"
        return formatter.string(from: date)
    }

    /// 「今日 13:42」「8/16 09:05」
    static func sightingTime(_ date: Date, now: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar.japanese
        formatter.timeZone = Calendar.japanese.timeZone
        if Calendar.japanese.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "'今日' HH:mm"
        } else {
            formatter.dateFormat = "M/d HH:mm"
        }
        return formatter.string(from: date)
    }

    /// 「450m」「1.2km」
    static func distance(_ meters: Double) -> String {
        if meters < 1000 { return "\(Int(meters.rounded()))m" }
        return String(format: "%.1fkm", meters / 1000)
    }

    /// 「238円」。価格不明（nil）のときは呼び出し側で非表示にする。
    static func price(_ yen: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let number = formatter.string(from: NSNumber(value: yen)) ?? "\(yen)"
        return "\(number)円"
    }

    /// 「4.4」。レビューが無ければ nil。
    static func rating(_ value: Double?) -> String? {
        guard let value else { return nil }
        return String(format: "%.1f", value)
    }
}
