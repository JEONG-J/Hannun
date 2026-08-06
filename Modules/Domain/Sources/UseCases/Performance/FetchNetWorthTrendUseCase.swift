//
//  FetchNetWorthTrendUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 추이 그래프의 시간 단위.
public enum TrendGranularity: String, Sendable, CaseIterable {
    case daily
    case monthly
}

/// 추이 그래프의 점 하나.
public struct NetWorthTrendPoint: Identifiable, Equatable, Sendable {
    // MARK: - Property

    public let date: Date
    public let total: Money

    /// 실측 없이 직전 값을 옮겨 적은 날인지 — `NetWorthRecord.isCarriedForward` 를 그대로 잇는다.
    ///
    /// 선을 끊지 않으려면 이 점도 그려야 하지만, 전일 대비 차분을 쓰는 쪽은 이 날을 걸러야
    /// 한다. 추이선과 캘린더가 같은 조회 결과에서 서로 다른 걸 볼 수 있게 하는 표식이다.
    public let isCarriedForward: Bool

    public var id: Date { date }

    // MARK: - Function

    public init(date: Date, total: Money, isCarriedForward: Bool = false) {
        self.date = date
        self.total = total
        self.isCarriedForward = isCarriedForward
    }
}

/// 저장된 스냅샷을 기간·단위에 맞게 추려 추이를 만든다.
public protocol FetchNetWorthTrendUseCaseProtocol: Sendable {
    func execute(
        from startDate: Date,
        to endDate: Date,
        granularity: TrendGranularity,
        baseCurrency: Currency
    ) async throws -> [NetWorthTrendPoint]
}

public struct FetchNetWorthTrendUseCase: FetchNetWorthTrendUseCaseProtocol {
    // MARK: - Property

    private let snapshotRepository: any SnapshotRepositoryProtocol
    private let calendar: Calendar

    // MARK: - Function

    public init(
        snapshotRepository: any SnapshotRepositoryProtocol,
        calendar: Calendar = .current
    ) {
        self.snapshotRepository = snapshotRepository
        self.calendar = calendar
    }

    public func execute(
        from startDate: Date,
        to endDate: Date,
        granularity: TrendGranularity,
        baseCurrency: Currency
    ) async throws -> [NetWorthTrendPoint] {
        let records = try await snapshotRepository.fetch(from: startDate, to: endDate)
        let sampled = switch granularity {
        case .daily: records
        case .monthly: Self.firstOfEachMonth(records, calendar: calendar)
        }

        return sampled.map {
            NetWorthTrendPoint(
                date: $0.recordedOn,
                total: $0.total(in: baseCurrency),
                isCarriedForward: $0.isCarriedForward
            )
        }
    }

    /// 월 단위 점은 각 달의 첫 스냅샷으로 대표한다 — 월별 기록을 따로 쌓지 않기 때문이다.
    static func firstOfEachMonth(
        _ records: [NetWorthRecord],
        calendar: Calendar
    ) -> [NetWorthRecord] {
        var seenMonths: Set<Date> = []

        return records.filter { record in
            let components = calendar.dateComponents([.year, .month], from: record.recordedOn)
            guard let month = calendar.date(from: components) else { return false }
            return seenMonths.insert(month).inserted
        }
    }
}
