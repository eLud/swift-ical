import Foundation

public struct RecurrenceExpansionOptions: Sendable, Equatable {
    public var maximumOccurrences: Int?
    public var maximumIterations: Int?
    public var maximumExpansionDuration: TimeInterval?

    public static let `default` = RecurrenceExpansionOptions()
    public static let unlimited = RecurrenceExpansionOptions(
        maximumOccurrences: nil,
        maximumIterations: nil,
        maximumExpansionDuration: nil
    )

    public init(
        maximumOccurrences: Int? = 100_000,
        maximumIterations: Int? = 2_000_000,
        maximumExpansionDuration: TimeInterval? = nil
    ) {
        self.maximumOccurrences = maximumOccurrences.map { max(1, $0) }
        self.maximumIterations = maximumIterations.map { max(1, $0) }
        self.maximumExpansionDuration = maximumExpansionDuration.map { max(0, $0) }
    }
}

public struct ICalRecurrenceRule: Sendable, Equatable, Hashable {
    public enum Frequency: String, Sendable, Equatable, Hashable {
        case secondly = "SECONDLY"
        case minutely = "MINUTELY"
        case hourly = "HOURLY"
        case daily = "DAILY"
        case weekly = "WEEKLY"
        case monthly = "MONTHLY"
        case yearly = "YEARLY"
    }

    public struct Weekday: Sendable, Equatable, Hashable {
        public enum Symbol: String, Sendable, Equatable, Hashable, CaseIterable {
            case sunday = "SU"
            case monday = "MO"
            case tuesday = "TU"
            case wednesday = "WE"
            case thursday = "TH"
            case friday = "FR"
            case saturday = "SA"

            var foundationWeekday: Int {
                switch self {
                case .sunday: 1
                case .monday: 2
                case .tuesday: 3
                case .wednesday: 4
                case .thursday: 5
                case .friday: 6
                case .saturday: 7
                }
            }
        }

        public var ordinal: Int?
        public var symbol: Symbol

        public init(ordinal: Int? = nil, symbol: Symbol) {
            self.ordinal = ordinal
            self.symbol = symbol
        }
    }

    public var frequency: Frequency
    public var until: ICalDateTime?
    public var count: Int?
    public var interval: Int
    public var bySecond: [Int]
    public var byMinute: [Int]
    public var byHour: [Int]
    public var byDay: [Weekday]
    public var byMonthDay: [Int]
    public var byYearDay: [Int]
    public var byWeekNo: [Int]
    public var byMonth: [Int]
    public var bySetPos: [Int]
    public var weekStart: Weekday.Symbol

    public init(
        frequency: Frequency,
        until: ICalDateTime? = nil,
        count: Int? = nil,
        interval: Int = 1,
        bySecond: [Int] = [],
        byMinute: [Int] = [],
        byHour: [Int] = [],
        byDay: [Weekday] = [],
        byMonthDay: [Int] = [],
        byYearDay: [Int] = [],
        byWeekNo: [Int] = [],
        byMonth: [Int] = [],
        bySetPos: [Int] = [],
        weekStart: Weekday.Symbol = .monday
    ) {
        self.frequency = frequency
        self.until = until
        self.count = count
        self.interval = max(1, interval)
        self.bySecond = bySecond
        self.byMinute = byMinute
        self.byHour = byHour
        self.byDay = byDay
        self.byMonthDay = byMonthDay
        self.byYearDay = byYearDay
        self.byWeekNo = byWeekNo
        self.byMonth = byMonth
        self.bySetPos = bySetPos
        self.weekStart = weekStart
    }

    public static func parse(_ raw: String) throws -> ICalRecurrenceRule {
        var fields: [String: String] = [:]
        for part in raw.split(separator: ";") {
            let pair = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else {
                throw ICalendarValueError.invalidRecurrenceRule(raw)
            }
            fields[String(pair[0]).uppercased()] = String(pair[1])
        }

        guard let frequencyRaw = fields["FREQ"],
              let frequency = Frequency(rawValue: frequencyRaw.uppercased())
        else {
            throw ICalendarValueError.invalidRecurrenceRule(raw)
        }

        return ICalRecurrenceRule(
            frequency: frequency,
            until: try fields["UNTIL"].map { try dateOrDateTime($0, rawRule: raw) },
            count: try fields["COUNT"].map { try positiveInt($0, rawRule: raw) },
            interval: try fields["INTERVAL"].map { try positiveInt($0, rawRule: raw) } ?? 1,
            bySecond: try intList(fields["BYSECOND"], range: 0...60, allowsZero: true, rawRule: raw),
            byMinute: try intList(fields["BYMINUTE"], range: 0...59, allowsZero: true, rawRule: raw),
            byHour: try intList(fields["BYHOUR"], range: 0...23, allowsZero: true, rawRule: raw),
            byDay: try weekdayList(fields["BYDAY"], rawRule: raw),
            byMonthDay: try intList(fields["BYMONTHDAY"], range: -31...31, allowsZero: false, rawRule: raw),
            byYearDay: try intList(fields["BYYEARDAY"], range: -366...366, allowsZero: false, rawRule: raw),
            byWeekNo: try intList(fields["BYWEEKNO"], range: -53...53, allowsZero: false, rawRule: raw),
            byMonth: try intList(fields["BYMONTH"], range: 1...12, allowsZero: false, rawRule: raw),
            bySetPos: try intList(fields["BYSETPOS"], range: -366...366, allowsZero: false, rawRule: raw),
            weekStart: try fields["WKST"].map { try weekdaySymbol($0, rawRule: raw) } ?? .monday
        )
    }

    public func occurrences(
        startingAt start: ICalDateTime,
        between rangeStart: Date,
        and rangeEnd: Date,
        timeZoneResolver: any ICalTimeZoneResolving = FoundationTimeZoneResolver(),
        expansionOptions: RecurrenceExpansionOptions = .default
    ) throws -> [Date] {
        guard rangeStart < rangeEnd else {
            return []
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZoneResolver.timeZone(for: start.kind)
        calendar.firstWeekday = weekStart.foundationWeekday
        calendar.minimumDaysInFirstWeek = 4

        let startDate = try start.dateValue(timeZoneResolver: timeZoneResolver)
        let untilDate = try until?.dateValue(timeZoneResolver: timeZoneResolver)
        let generationEnd = minDate(untilDate, rangeEnd)
        let isDateOnly = start.kind == .date
        try expansionOptions.validateDuration(from: startDate, to: generationEnd)

        var generated: [Date] = []
        switch frequency {
        case .secondly, .minutely, .hourly:
            generated = try generateSubdaily(
                from: startDate,
                through: generationEnd,
                calendar: calendar,
                isDateOnly: isDateOnly,
                expansionOptions: expansionOptions
            )
        case .daily, .weekly, .monthly, .yearly:
            generated = try generateByDate(
                from: startDate,
                through: generationEnd,
                calendar: calendar,
                isDateOnly: isDateOnly,
                expansionOptions: expansionOptions
            )
        }

        if let count {
            generated = Array(generated.prefix(count))
        }

        return generated.filter { $0 >= rangeStart && $0 < rangeEnd }
    }

    private func generateSubdaily(
        from start: Date,
        through end: Date,
        calendar: Calendar,
        isDateOnly: Bool,
        expansionOptions: RecurrenceExpansionOptions
    ) throws -> [Date] {
        var result: [Date] = []
        var iterations = 0
        let startPeriod = startOfSubdailyPeriod(containing: start, calendar: calendar)
        var period = startOfSubdailyPeriod(containing: start, calendar: calendar)

        while period <= end {
            iterations += 1
            try expansionOptions.validateIterations(iterations)
            if matchesSubdailyPeriodInterval(period, startPeriod: startPeriod, calendar: calendar),
               matchesDateFilters(period, start: start, calendar: calendar) {
                let candidates = try subdailyCandidates(in: period, start: start, through: end, calendar: calendar, isDateOnly: isDateOnly)
                let selected = bySetPos.isEmpty ? candidates : selectedBySetPositions(from: candidates)
                for candidate in selected where candidate >= start {
                    try append(candidate, to: &result, expansionOptions: expansionOptions)
                    if hasReachedCount(result) {
                        return result
                    }
                }
            }
            guard let next = calendar.date(byAdding: subdailyPeriodComponent, value: 1, to: period) else {
                break
            }
            period = next
        }

        return result
    }

    private func subdailyCandidates(in period: Date, start: Date, through end: Date, calendar: Calendar, isDateOnly: Bool) throws -> [Date] {
        guard !isDateOnly else {
            return [period].filter { $0 <= end }
        }

        let startComponents = calendar.dateComponents([.minute, .second], from: start)
        let periodComponents = calendar.dateComponents([.hour, .minute, .second], from: period)
        let periodHour = periodComponents.hour ?? 0
        let periodMinute = periodComponents.minute ?? 0
        let periodSecond = periodComponents.second ?? 0

        switch frequency {
        case .hourly:
            guard byHour.isEmpty || byHour.contains(periodHour) else {
                return []
            }
            return subdailyDates(
                on: period,
                hours: [periodHour],
                minutes: byMinute.isEmpty ? [startComponents.minute ?? 0] : byMinute,
                seconds: bySecond.isEmpty ? [startComponents.second ?? 0] : bySecond,
                calendar: calendar,
                through: end
            )
        case .minutely:
            guard (byHour.isEmpty || byHour.contains(periodHour)),
                  (byMinute.isEmpty || byMinute.contains(periodMinute))
            else {
                return []
            }
            return subdailyDates(
                on: period,
                hours: [periodHour],
                minutes: [periodMinute],
                seconds: bySecond.isEmpty ? [startComponents.second ?? 0] : bySecond,
                calendar: calendar,
                through: end
            )
        case .secondly:
            guard (byHour.isEmpty || byHour.contains(periodHour)),
                  (byMinute.isEmpty || byMinute.contains(periodMinute)),
                  (bySecond.isEmpty || bySecond.contains(periodSecond))
            else {
                return []
            }
            return [period].filter { $0 <= end }
        default:
            throw ICalendarValueError.unsupportedRecurrence(frequency.rawValue)
        }
    }

    private func subdailyDates(
        on period: Date,
        hours: [Int],
        minutes: [Int],
        seconds: [Int],
        calendar: Calendar,
        through end: Date
    ) -> [Date] {
        var result: [Date] = []
        for hour in hours.sorted() {
            for minute in minutes.sorted() {
                for second in seconds.sorted() {
                    if let candidate = calendar.date(bySettingHour: hour, minute: minute, second: second, of: period),
                       candidate <= end {
                        result.append(candidate)
                    }
                }
            }
        }
        return Array(Set(result)).sorted()
    }

    private func generateByDate(
        from start: Date,
        through end: Date,
        calendar: Calendar,
        isDateOnly: Bool,
        expansionOptions: RecurrenceExpansionOptions
    ) throws -> [Date] {
        if bySetPos.isEmpty {
            return try generateByDateWithoutSetPosition(
                from: start,
                through: end,
                calendar: calendar,
                isDateOnly: isDateOnly,
                expansionOptions: expansionOptions
            )
        }

        return try generateByDateWithSetPosition(
            from: start,
            through: end,
            calendar: calendar,
            isDateOnly: isDateOnly,
            expansionOptions: expansionOptions
        )
    }

    private func generateByDateWithoutSetPosition(
        from start: Date,
        through end: Date,
        calendar: Calendar,
        isDateOnly: Bool,
        expansionOptions: RecurrenceExpansionOptions
    ) throws -> [Date] {
        var result: [Date] = []
        var iterations = 0
        var day = calendar.startOfDay(for: start)

        while day <= end {
            iterations += 1
            try expansionOptions.validateIterations(iterations)
            if matchesFrequencyInterval(day, start: start, calendar: calendar),
               matchesDateFilters(day, start: start, calendar: calendar) {
                let times = candidateTimes(start: start, calendar: calendar, isDateOnly: isDateOnly)
                for time in times {
                    guard let candidate = calendar.date(
                        bySettingHour: time.hour,
                        minute: time.minute,
                        second: time.second,
                        of: day
                    ), candidate <= end,
                       matchesTimeFilters(candidate, calendar: calendar, isDateOnly: isDateOnly),
                       candidate >= start
                    else {
                        continue
                    }
                    try append(candidate, to: &result, expansionOptions: expansionOptions)
                    if hasReachedCount(result) {
                        return result
                    }
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = next
        }

        return result
    }

    private func generateByDateWithSetPosition(
        from start: Date,
        through end: Date,
        calendar: Calendar,
        isDateOnly: Bool,
        expansionOptions: RecurrenceExpansionOptions
    ) throws -> [Date] {
        var grouped: [PeriodKey: [Date]] = [:]
        var result: [Date] = []
        var iterations = 0
        var day = startOfPeriod(containing: start, calendar: calendar)

        while day <= end {
            iterations += 1
            try expansionOptions.validateIterations(iterations)
            if matchesFrequencyInterval(day, start: start, calendar: calendar),
               matchesDateFilters(day, start: start, calendar: calendar) {
                let times = candidateTimes(start: start, calendar: calendar, isDateOnly: isDateOnly)
                for time in times {
                    guard let candidate = calendar.date(
                        bySettingHour: time.hour,
                        minute: time.minute,
                        second: time.second,
                        of: day
                    ), candidate <= end,
                       matchesTimeFilters(candidate, calendar: calendar, isDateOnly: isDateOnly)
                    else {
                        continue
                    }
                    grouped[PeriodKey(date: candidate, frequency: frequency, calendar: calendar), default: []].append(candidate)
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            if PeriodKey(date: next, frequency: frequency, calendar: calendar) != PeriodKey(date: day, frequency: frequency, calendar: calendar) {
                if try appendSelectedSetPositions(from: &grouped, to: &result, start: start, expansionOptions: expansionOptions) {
                    return result
                }
                if hasReachedCount(result) {
                    return result
                }
            }
            day = next
        }

        _ = try appendSelectedSetPositions(from: &grouped, to: &result, start: start, expansionOptions: expansionOptions)
        return result
    }

    private func appendSelectedSetPositions(
        from grouped: inout [PeriodKey: [Date]],
        to result: inout [Date],
        start: Date,
        expansionOptions: RecurrenceExpansionOptions
    ) throws -> Bool {
        for key in grouped.keys.sorted() {
            let candidates = Array(Set(grouped[key] ?? [])).sorted()
            for candidate in selectedBySetPositions(from: candidates) where candidate >= start {
                try append(candidate, to: &result, expansionOptions: expansionOptions)
                if hasReachedCount(result) {
                    grouped.removeAll(keepingCapacity: true)
                    return true
                }
            }
        }
        grouped.removeAll(keepingCapacity: true)
        return false
    }

    private func append(_ date: Date, to result: inout [Date], expansionOptions: RecurrenceExpansionOptions) throws {
        if let maximumOccurrences = expansionOptions.maximumOccurrences,
           result.count >= maximumOccurrences {
            throw ICalendarRecurrenceError.occurrenceLimitExceeded(limit: maximumOccurrences)
        }
        result.append(date)
    }

    private func hasReachedCount(_ result: [Date]) -> Bool {
        if let count {
            return result.count >= count
        }
        return false
    }

    private func candidateTimes(start: Date, calendar: Calendar, isDateOnly: Bool) -> [(hour: Int, minute: Int, second: Int)] {
        let components = calendar.dateComponents([.hour, .minute, .second], from: start)
        if isDateOnly {
            return [(components.hour ?? 0, components.minute ?? 0, components.second ?? 0)]
        }
        let hours = byHour.isEmpty ? [components.hour ?? 0] : byHour
        let minutes = byMinute.isEmpty ? [components.minute ?? 0] : byMinute
        let seconds = bySecond.isEmpty ? [components.second ?? 0] : bySecond
        return hours.flatMap { hour in
            minutes.flatMap { minute in
                seconds.map { second in
                    (hour, minute, second)
                }
            }
        }
    }

    private func matchesFilters(_ date: Date, start: Date, calendar: Calendar, isDateOnly: Bool) -> Bool {
        matchesFrequencyInterval(date, start: start, calendar: calendar) &&
            matchesDateFilters(date, start: start, calendar: calendar) &&
            matchesTimeFilters(date, calendar: calendar, isDateOnly: isDateOnly)
    }

    private func matchesFrequencyInterval(_ date: Date, start: Date, calendar: Calendar) -> Bool {
        switch frequency {
        case .secondly:
            return (calendar.dateComponents([.second], from: start, to: date).second ?? 0) % interval == 0
        case .minutely:
            return (calendar.dateComponents([.minute], from: start, to: date).minute ?? 0) % interval == 0
        case .hourly:
            return (calendar.dateComponents([.hour], from: start, to: date).hour ?? 0) % interval == 0
        case .daily:
            return (calendar.dateComponents([.day], from: calendar.startOfDay(for: start), to: calendar.startOfDay(for: date)).day ?? 0) % interval == 0
        case .weekly:
            let days = calendar.dateComponents([.day], from: startOfWeek(for: start, calendar: calendar), to: startOfWeek(for: date, calendar: calendar)).day ?? 0
            return (days / 7) % interval == 0
        case .monthly:
            let startComponents = calendar.dateComponents([.year, .month], from: start)
            let dateComponents = calendar.dateComponents([.year, .month], from: date)
            guard let startYear = startComponents.year,
                  let startMonth = startComponents.month,
                  let dateYear = dateComponents.year,
                  let dateMonth = dateComponents.month
            else {
                return false
            }
            let months = (dateYear - startYear) * 12 + (dateMonth - startMonth)
            return months >= 0 && months % interval == 0
        case .yearly:
            let startMatchesWeekYearRule = !byWeekNo.isEmpty &&
                matchesDateFilters(start, start: start, calendar: calendar)
            let component: Calendar.Component = startMatchesWeekYearRule ? .yearForWeekOfYear : .year
            let startYear = calendar.component(component, from: start)
            let dateYear = calendar.component(component, from: date)
            let years = dateYear - startYear
            return years >= 0 && years % interval == 0
        }
    }

    private func matchesDateFilters(_ date: Date, start: Date, calendar: Calendar) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day, .weekday, .weekdayOrdinal, .weekOfYear], from: date)
        let startComponents = calendar.dateComponents([.month, .day, .weekday], from: start)

        if !byMonth.isEmpty, !byMonth.contains(components.month ?? -1) {
            return false
        }
        if frequency == .yearly,
           byMonth.isEmpty,
           !byMonthDay.isEmpty,
           byYearDay.isEmpty,
           byWeekNo.isEmpty,
           components.month != startComponents.month {
            return false
        }
        if !byMonthDay.isEmpty, !matchesMonthDay(components.day ?? -1, date: date, calendar: calendar) {
            return false
        }
        if !byYearDay.isEmpty, !matchesYearDay(date, calendar: calendar) {
            return false
        }
        if !byWeekNo.isEmpty, !matchesWeekNo(components.weekOfYear ?? -1, date: date, calendar: calendar) {
            return false
        }
        if !byWeekNo.isEmpty,
           byDay.isEmpty,
           byMonthDay.isEmpty,
           byYearDay.isEmpty,
           components.weekday != startComponents.weekday {
            return false
        }
        if !byDay.isEmpty, !matchesWeekday(date, start: start, calendar: calendar) {
            return false
        }
        if byDay.isEmpty && byMonthDay.isEmpty && byYearDay.isEmpty && byWeekNo.isEmpty {
            switch frequency {
            case .weekly:
                return components.weekday == startComponents.weekday
            case .monthly:
                return components.day == startComponents.day
            case .yearly:
                return components.month == (byMonth.isEmpty ? startComponents.month : components.month) &&
                    components.day == startComponents.day
            default:
                break
            }
        }
        return true
    }

    private func matchesTimeFilters(_ date: Date, calendar: Calendar, isDateOnly: Bool) -> Bool {
        if isDateOnly {
            return true
        }
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        if !byHour.isEmpty, !byHour.contains(components.hour ?? -1) {
            return false
        }
        if !byMinute.isEmpty, !byMinute.contains(components.minute ?? -1) {
            return false
        }
        if !bySecond.isEmpty, !bySecond.contains(components.second ?? -1) {
            return false
        }
        return true
    }

    private func matchesMonthDay(_ day: Int, date: Date, calendar: Calendar) -> Bool {
        let monthDays = calendar.range(of: .day, in: .month, for: date)?.count ?? 31
        return byMonthDay.contains { value in
            value > 0 ? value == day : monthDays + value + 1 == day
        }
    }

    private func matchesYearDay(_ date: Date, calendar: Calendar) -> Bool {
        let day = calendar.ordinality(of: .day, in: .year, for: date) ?? -1
        let yearDays = calendar.range(of: .day, in: .year, for: date)?.count ?? 366
        return byYearDay.contains { value in
            value > 0 ? value == day : yearDays + value + 1 == day
        }
    }

    private func matchesWeekNo(_ week: Int, date: Date, calendar: Calendar) -> Bool {
        let weeks = calendar.range(of: .weekOfYear, in: .yearForWeekOfYear, for: date)?.count ?? 53
        return byWeekNo.contains { value in
            value > 0 ? value == week : weeks + value + 1 == week
        }
    }

    private func matchesWeekday(_ date: Date, start: Date, calendar: Calendar) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return byDay.contains { ruleDay in
            guard ruleDay.symbol.foundationWeekday == weekday else {
                return false
            }
            guard let ordinal = ruleDay.ordinal else {
                return true
            }
            switch frequency {
            case .yearly:
                let ordinalScope: Calendar.Component = byMonth.isEmpty ? .year : .month
                return nthWeekdayOrdinal(in: ordinalScope, for: date, calendar: calendar) == ordinal
            default:
                return nthWeekdayOrdinal(in: .month, for: date, calendar: calendar) == ordinal
            }
        }
    }

    private func nthWeekdayOrdinal(in larger: Calendar.Component, for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        guard let interval = calendar.dateInterval(of: larger, for: date) else {
            return 0
        }
        var matches: [Date] = []
        var current = interval.start
        while current < interval.end {
            if calendar.component(.weekday, from: current) == weekday {
                matches.append(current)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? interval.end
        }
        guard let index = matches.firstIndex(where: { calendar.isDate($0, inSameDayAs: date) }) else {
            return 0
        }
        let positive = index + 1
        let negative = index - matches.count
        return byDay.contains(where: { $0.ordinal == negative }) ? negative : positive
    }

    private func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    private func startOfPeriod(containing date: Date, calendar: Calendar) -> Date {
        switch frequency {
        case .yearly:
            return calendar.dateInterval(of: .year, for: date)?.start ?? calendar.startOfDay(for: date)
        case .monthly:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        case .weekly:
            return startOfWeek(for: date, calendar: calendar)
        default:
            return calendar.startOfDay(for: date)
        }
    }

    private var subdailyPeriodComponent: Calendar.Component {
        switch frequency {
        case .hourly:
            return .hour
        case .minutely:
            return .minute
        default:
            return .second
        }
    }

    private func startOfSubdailyPeriod(containing date: Date, calendar: Calendar) -> Date {
        let components: Set<Calendar.Component>
        switch frequency {
        case .hourly:
            components = [.year, .month, .day, .hour]
        case .minutely:
            components = [.year, .month, .day, .hour, .minute]
        default:
            components = [.year, .month, .day, .hour, .minute, .second]
        }
        return calendar.date(from: calendar.dateComponents(components, from: date)) ?? date
    }

    private func matchesSubdailyPeriodInterval(_ period: Date, startPeriod: Date, calendar: Calendar) -> Bool {
        switch frequency {
        case .hourly:
            return (calendar.dateComponents([.hour], from: startPeriod, to: period).hour ?? 0) % interval == 0
        case .minutely:
            return (calendar.dateComponents([.minute], from: startPeriod, to: period).minute ?? 0) % interval == 0
        case .secondly:
            return (calendar.dateComponents([.second], from: startPeriod, to: period).second ?? 0) % interval == 0
        default:
            return false
        }
    }

    private func selectedBySetPositions(from candidates: [Date]) -> [Date] {
        let sortedCandidates = Array(Set(candidates)).sorted()
        return Array(Set(bySetPos.compactMap { position in
            let index = position > 0 ? position - 1 : sortedCandidates.count + position
            guard sortedCandidates.indices.contains(index) else {
                return nil
            }
            return sortedCandidates[index]
        })).sorted()
    }

}

private struct PeriodKey: Hashable, Comparable {
    var year: Int
    var month: Int
    var week: Int
    var day: Int
    var hour: Int
    var minute: Int
    var second: Int
    var frequencyRank: Int

    init(date: Date, frequency: ICalRecurrenceRule.Frequency, calendar: Calendar) {
        let components = calendar.dateComponents([.year, .month, .weekOfYear, .day, .hour, .minute, .second], from: date)
        year = components.year ?? 0
        month = components.month ?? 0
        week = components.weekOfYear ?? 0
        day = components.day ?? 0
        hour = components.hour ?? 0
        minute = components.minute ?? 0
        second = components.second ?? 0
        switch frequency {
        case .yearly:
            frequencyRank = 0
            month = 0; week = 0; day = 0; hour = 0; minute = 0; second = 0
        case .monthly:
            frequencyRank = 1
            week = 0; day = 0; hour = 0; minute = 0; second = 0
        case .weekly:
            frequencyRank = 2
            month = 0; day = 0; hour = 0; minute = 0; second = 0
        case .daily:
            frequencyRank = 3
            hour = 0; minute = 0; second = 0
        case .hourly:
            frequencyRank = 4
            minute = 0; second = 0
        case .minutely:
            frequencyRank = 5
            second = 0
        case .secondly:
            frequencyRank = 6
        }
    }

    static func < (lhs: PeriodKey, rhs: PeriodKey) -> Bool {
        let left = [lhs.year, lhs.month, lhs.week, lhs.day, lhs.hour, lhs.minute, lhs.second, lhs.frequencyRank]
        let right = [rhs.year, rhs.month, rhs.week, rhs.day, rhs.hour, rhs.minute, rhs.second, rhs.frequencyRank]
        for index in left.indices {
            if left[index] != right[index] {
                return left[index] < right[index]
            }
        }
        return false
    }
}

private func minDate(_ optional: Date?, _ fallback: Date) -> Date {
    guard let optional else {
        return fallback
    }
    return min(optional, fallback)
}

private func positiveInt(_ raw: String, rawRule: String) throws -> Int {
    guard let value = Int(raw), value > 0 else {
        throw ICalendarValueError.invalidRecurrenceRule(rawRule)
    }
    return value
}

private func intList(_ raw: String?, range: ClosedRange<Int>, allowsZero: Bool, rawRule: String) throws -> [Int] {
    guard let raw, !raw.isEmpty else {
        return []
    }
    return try raw.split(separator: ",").map {
        guard let value = Int($0),
              range.contains(value),
              (allowsZero || value != 0)
        else {
            throw ICalendarValueError.invalidRecurrenceRule(rawRule)
        }
        return value
    }
}

private func dateOrDateTime(_ raw: String, rawRule: String) throws -> ICalDateTime {
    if raw.contains("T") {
        return try ICalDateTime.parse(raw)
    }
    do {
        let date = try ICalDate.parse(raw)
        return ICalDateTime(date: date, hour: 0, minute: 0, second: 0, kind: .date)
    } catch {
        throw ICalendarValueError.invalidRecurrenceRule(rawRule)
    }
}

private func weekdayList(_ raw: String?, rawRule: String) throws -> [ICalRecurrenceRule.Weekday] {
    guard let raw, !raw.isEmpty else {
        return []
    }
    return try raw.split(separator: ",").map { token in
        let text = String(token).uppercased()
        let symbolText = String(text.suffix(2))
        let symbol = try weekdaySymbol(symbolText, rawRule: rawRule)
        let prefix = String(text.dropLast(2))
        let ordinal = prefix.isEmpty ? nil : Int(prefix)
        if !prefix.isEmpty {
            guard let ordinal,
                  ordinal != 0,
                  (-53...53).contains(ordinal)
            else {
                throw ICalendarValueError.invalidRecurrenceRule(rawRule)
            }
        }
        return ICalRecurrenceRule.Weekday(ordinal: ordinal, symbol: symbol)
    }
}

private func weekdaySymbol(_ raw: String, rawRule: String) throws -> ICalRecurrenceRule.Weekday.Symbol {
    guard let symbol = ICalRecurrenceRule.Weekday.Symbol(rawValue: raw.uppercased()) else {
        throw ICalendarValueError.invalidRecurrenceRule(rawRule)
    }
    return symbol
}

private extension RecurrenceExpansionOptions {
    func validateIterations(_ iterations: Int) throws {
        if let maximumIterations, iterations > maximumIterations {
            throw ICalendarRecurrenceError.iterationLimitExceeded(limit: maximumIterations)
        }
    }

    func validateDuration(from start: Date, to end: Date) throws {
        guard let maximumExpansionDuration else {
            return
        }
        if end.timeIntervalSince(start) > maximumExpansionDuration {
            throw ICalendarRecurrenceError.expansionDurationExceeded(maximum: maximumExpansionDuration)
        }
    }
}
