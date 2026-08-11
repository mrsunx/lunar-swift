import Foundation
import Testing
@testable import LunarSwift

#if canImport(Darwin)
import Darwin
#endif

@Suite("Lunar 性能与结果基线", .serialized)
struct LunarPerformanceTests {
    private static let sampleYears = Array(1900 ..< 2000)

    @Test("1900 至 2099 年历法结果摘要保持稳定")
    func resultSnapshot() {
        var lunarYearDigest = StableDigest()
        var lunarDigest = StableDigest()

        for year in 1900 ... 2099 {
            let lunarYear = LunarYear(lunarYear: year)
            lunarYearDigest.combine(lunarYear.year)
            lunarYearDigest.combine(lunarYear.ganZhi)
            lunarYearDigest.combine(lunarYear.leapMonth)
            lunarYearDigest.combine(lunarYear.dayCount)
            for julianDay in lunarYear.jieQiJulianDays {
                lunarYearDigest.combine(julianDay)
            }
            for month in lunarYear.months {
                lunarYearDigest.combine(month.year)
                lunarYearDigest.combine(month.month)
                lunarYearDigest.combine(month.dayCount)
                lunarYearDigest.combine(month.firstJulianDay)
                lunarYearDigest.combine(month.index)
            }

            let samples = [
                Solar.fromYmdHms(year: year, month: 1, day: 1, hour: 0),
                Solar.fromYmdHms(year: year, month: 2, day: 4, hour: 12),
                Solar.fromYmdHms(year: year, month: 6, day: 15, hour: 23),
                Solar.fromYmdHms(year: year, month: 12, day: 31, hour: 23, minute: 59, second: 59)
            ]
            for solar in samples {
                let lunar = solar.lunar
                let eightChar = lunar.eightChar
                lunarDigest.combine(solar.ymdhms)
                lunarDigest.combine(solar.festivals.joined(separator: "|"))
                lunarDigest.combine(solar.otherFestivals.joined(separator: "|"))
                lunarDigest.combine(lunar.year)
                lunarDigest.combine(lunar.month)
                lunarDigest.combine(lunar.day)
                lunarDigest.combine(lunar.solar.ymdhms)
                lunarDigest.combine(lunar.yearInGanZhi)
                lunarDigest.combine(lunar.yearInGanZhiExact)
                lunarDigest.combine(lunar.monthInGanZhi)
                lunarDigest.combine(lunar.monthInGanZhiExact)
                lunarDigest.combine(lunar.dayInGanZhi)
                lunarDigest.combine(lunar.dayInGanZhiExact)
                lunarDigest.combine(lunar.timeInGanZhi)
                lunarDigest.combine(eightChar.year)
                lunarDigest.combine(eightChar.month)
                lunarDigest.combine(eightChar.day)
                lunarDigest.combine(eightChar.time)
                lunarDigest.combine(lunar.jieQi)
                lunarDigest.combine(lunar.hou)
                lunarDigest.combine(lunar.festivals.joined(separator: "|"))
                lunarDigest.combine(lunar.otherFestivals.joined(separator: "|"))
                lunarDigest.combine(Foto.fromLunar(lunar: lunar).fullString)
                lunarDigest.combine(
                    Foto.fromLunar(lunar: lunar).festivals
                        .map(\.fullString)
                        .joined(separator: "|")
                )
                lunarDigest.combine(Tao.fromLunar(lunar: lunar).fullString)
                lunarDigest.combine(
                    Tao.fromLunar(lunar: lunar).festivals
                        .map(\.fullString)
                        .joined(separator: "|")
                )
            }
        }

        print("[LunarResultBaseline] lunar_year_digest=\(lunarYearDigest.value) lunar_digest=\(lunarDigest.value)")
        #expect(lunarYearDigest.value == 5_334_280_502_400_707_671)
        #expect(lunarDigest.value == 2_248_901_251_296_567_815)
    }

    @Test("年度缓存严格有界并按最近使用淘汰")
    func boundedCache() {
        let cache = LunarYearCache(capacity: 2)
        let first = cache.value(for: 1991) { LunarYear(lunarYear: 1991) }
        let second = cache.value(for: 2026) { LunarYear(lunarYear: 2026) }
        #expect(cache.value(for: 1991) { LunarYear(lunarYear: 1991) } === first)

        _ = cache.value(for: 2036) { LunarYear(lunarYear: 2036) }

        #expect(cache.count == 2)
        #expect(cache.value(for: 1991) { LunarYear(lunarYear: 1991) } === first)
        #expect(cache.value(for: 2026) { LunarYear(lunarYear: 2026) } !== second)
    }

    @Test("同一年并发首次请求只创建一次")
    func concurrentFirstRequest() {
        let cache = LunarYearCache(capacity: 128)
        let result = LockedCacheProbe()

        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            let value = cache.value(for: 2026) {
                result.didCreate()
                return LunarYear(lunarYear: 2026)
            }
            result.record(value)
        }

        #expect(result.creationCount == 1)
        #expect(result.identitiesCount == 1)
        #expect(cache.count == 1)
    }

    @Test("年度缓存填满及淘汰后保持容量上限")
    func cacheCapacityAndMemory() {
        for capacity in [1, 10, 100, 128] {
            let cache = LunarYearCache(capacity: capacity)
            let before = peakResidentMemoryBytes()
            for year in 1900 ..< 1900 + capacity {
                _ = cache.value(for: year) { LunarYear(lunarYear: year) }
            }
            let filled = peakResidentMemoryBytes()
            for year in 2100 ..< 2100 + capacity * 2 {
                _ = cache.value(for: year) { LunarYear(lunarYear: year) }
            }
            let evicted = peakResidentMemoryBytes()
            print(
                "[LunarCacheMemory] capacity=\(capacity) before=\(before) "
                    + "filled=\(filled) after_eviction=\(evicted) count=\(cache.count)"
            )
            #expect(cache.count == capacity)
        }
    }

    @Test("LunarYear 和 Lunar 构造性能基线")
    func constructionPerformance() {
        let metrics = [
            measure(name: "lunar_year_100_direct") {
                Self.sampleYears.reduce(into: 0) { checksum, year in
                    checksum &+= LunarYear(lunarYear: year).dayCount
                }
            },
            measure(name: "lunar_year_100_from_year") {
                Self.sampleYears.reduce(into: 0) { checksum, year in
                    checksum &+= LunarYear.fromYear(lunarYear: year).dayCount
                }
            },
            measure(name: "lunar_year_100_alternating") {
                (0 ..< 100).reduce(into: 0) { checksum, index in
                    let year = index.isMultiple(of: 2) ? 1991 : 2026
                    checksum &+= LunarYear.fromYear(lunarYear: year).dayCount
                }
            },
            measure(name: "lunar_100_same_year") {
                (0 ..< 100).reduce(into: 0) { checksum, index in
                    let solar = Solar.fromYmdHms(
                        year: 2026,
                        month: index % 12 + 1,
                        day: index % 27 + 1,
                        hour: index % 24
                    )
                    checksum &+= solar.lunar.dayZhiIndex
                }
            },
            measure(name: "lunar_100_adjacent_years") {
                (0 ..< 100).reduce(into: 0) { checksum, index in
                    let solar = Solar.fromYmdHms(
                        year: 2024 + index % 5,
                        month: index % 12 + 1,
                        day: index % 27 + 1,
                        hour: index % 24
                    )
                    checksum &+= solar.lunar.dayZhiIndex
                }
            },
            measure(name: "lunar_100_spanning_years") {
                Self.sampleYears.reduce(into: 0) { checksum, year in
                    let solar = Solar.fromYmdHms(year: year, month: 6, day: 15, hour: 12)
                    checksum &+= solar.lunar.dayZhiIndex
                }
            },
            measure(name: "lunar_100_direct_lunar_date") {
                Self.sampleYears.reduce(into: 0) { checksum, year in
                    let lunar = Lunar.fromYmdHms(
                        lunarYear: year,
                        lunarMonth: 1,
                        lunarDay: 1,
                        hour: 12
                    )
                    checksum &+= lunar.solar.day
                }
            },
            measure(name: "lunar_100_from_date") {
                Self.sampleYears.reduce(into: 0) { checksum, year in
                    var components = DateComponents()
                    components.calendar = Calendar(identifier: .gregorian)
                    components.timeZone = TimeZone(secondsFromGMT: 8 * 3_600)
                    components.year = year
                    components.month = 6
                    components.day = 15
                    components.hour = 12
                    let lunar = Lunar.fromDate(date: components.date!)
                    checksum &+= lunar.dayZhiIndex
                }
            }
        ]

        for metric in metrics {
            metric.printResult()
            #expect(metric.checksum != Int.min)
        }
    }

    @Test("冷缓存首次访问与第二次访问分别测量")
    func firstAndSecondAccessPerformance() {
        var firstDurations: [Double] = []
        var secondDurations: [Double] = []
        var checksum = 0

        for _ in 0 ..< 10 {
            LunarYear.yearCache.removeAll()
            let firstStart = ContinuousClock.now
            checksum &+= LunarYear.fromYear(lunarYear: 2026).dayCount
            firstDurations.append(milliseconds(from: firstStart.duration(to: .now)))

            let secondStart = ContinuousClock.now
            checksum &+= LunarYear.fromYear(lunarYear: 2026).dayCount
            secondDurations.append(milliseconds(from: secondStart.duration(to: .now)))
        }

        PerformanceMetric(
            name: "lunar_year_first_access",
            durations: firstDurations,
            residentMemoryBefore: 0,
            residentMemoryAfter: 0,
            checksum: checksum
        ).printResult()
        PerformanceMetric(
            name: "lunar_year_second_access",
            durations: secondDurations,
            residentMemoryBefore: 0,
            residentMemoryAfter: 0,
            checksum: checksum
        ).printResult()
        #expect(firstDurations.count == secondDurations.count)
    }

    @Test("ShouXingUtil 关键方法性能基线")
    func shouXingPerformance() {
        let metrics = [
            measure(name: "shouxing_calc_qi_100") {
                (0 ..< 100).reduce(into: 0) { checksum, index in
                    let value = ShouXingUtil.calcQi(pjd: Double(index - 50) * 365.2422)
                    checksum &+= Int(value)
                }
            },
            measure(name: "shouxing_qi_accurate2_100") {
                (0 ..< 100).reduce(into: 0) { checksum, index in
                    let value = ShouXingUtil.qiAccurate2(jd: Double(index - 50) * 365.2422)
                    checksum &+= Int(value)
                }
            },
            measure(name: "shouxing_calc_shuo_100") {
                (0 ..< 100).reduce(into: 0) { checksum, index in
                    let value = ShouXingUtil.calcShuo(pjd: Double(index - 50) * 365.2422)
                    checksum &+= Int(value)
                }
            }
        ]

        for metric in metrics {
            metric.printResult()
            #expect(metric.checksum != Int.min)
        }
    }
}

private final class LockedCacheProbe {
    private let lock = NSLock()
    private var creations = 0
    private var identities: Set<ObjectIdentifier> = []

    var creationCount: Int {
        lock.withLock { creations }
    }

    var identitiesCount: Int {
        lock.withLock { identities.count }
    }

    func didCreate() {
        lock.withLock { creations += 1 }
    }

    func record(_ value: LunarYear) {
        lock.withLock { _ = identities.insert(ObjectIdentifier(value)) }
    }
}

private struct PerformanceMetric {
    let name: String
    let durations: [Double]
    let residentMemoryBefore: UInt64
    let residentMemoryAfter: UInt64
    let checksum: Int

    var totalMilliseconds: Double {
        durations.reduce(0, +)
    }

    var averageMilliseconds: Double {
        totalMilliseconds / Double(durations.count)
    }

    var medianMilliseconds: Double {
        let sorted = durations.sorted()
        let middle = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[middle - 1] + sorted[middle]) / 2
        }
        return sorted[middle]
    }

    var residentMemoryDelta: Int64 {
        Int64(residentMemoryAfter) - Int64(residentMemoryBefore)
    }

    func printResult() {
        print(
            "[LunarPerformance] name=\(name) samples=\(durations.count) "
                + "total_ms=\(formatted(totalMilliseconds)) "
                + "average_ms=\(formatted(averageMilliseconds)) "
                + "median_ms=\(formatted(medianMilliseconds)) "
                + "rss_before=\(residentMemoryBefore) "
                + "rss_after=\(residentMemoryAfter) "
                + "rss_delta=\(residentMemoryDelta) checksum=\(checksum)"
        )
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.3f", value)
    }
}

private func measure(
    name: String,
    samples: Int = 5,
    operation: () -> Int
) -> PerformanceMetric {
    let residentMemoryBefore = peakResidentMemoryBytes()
    var durations: [Double] = []
    var checksum = 0
    for _ in 0 ..< samples {
        let start = ContinuousClock.now
        checksum &+= operation()
        durations.append(milliseconds(from: start.duration(to: .now)))
    }
    return PerformanceMetric(
        name: name,
        durations: durations,
        residentMemoryBefore: residentMemoryBefore,
        residentMemoryAfter: peakResidentMemoryBytes(),
        checksum: checksum
    )
}

private func milliseconds(from duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) * 1_000
        + Double(components.attoseconds) / 1_000_000_000_000_000
}

private func peakResidentMemoryBytes() -> UInt64 {
#if canImport(Darwin)
    var usage = rusage()
    guard getrusage(RUSAGE_SELF, &usage) == 0 else {
        return 0
    }
    return UInt64(usage.ru_maxrss)
#else
    return 0
#endif
}

private struct StableDigest {
    private(set) var value: UInt64 = 14_695_981_039_346_656_037

    mutating func combine(_ value: String) {
        for byte in value.utf8 {
            combine(byte)
        }
        combine(0xFF)
    }

    mutating func combine(_ value: Int) {
        combine(UInt64(bitPattern: Int64(value)))
    }

    mutating func combine(_ value: Double) {
        combine(value.bitPattern)
    }

    private mutating func combine(_ value: UInt64) {
        for shift in stride(from: 0, to: 64, by: 8) {
            combine(UInt8(truncatingIfNeeded: value >> UInt64(shift)))
        }
    }

    private mutating func combine(_ byte: UInt8) {
        value ^= UInt64(byte)
        value &*= 1_099_511_628_211
    }
}
