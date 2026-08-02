//
//  CalculateYTDReturnUseCase.swift
//  HannunDomain
//
//  Created by euijjang97 on 8/1/26.
//

import Foundation
import HannunCore

/// 연초 대비 순수 투자 성과.
public struct YTDReturn: Equatable, Sendable {
    // MARK: - Property

    public let openingBalance: Money
    public let closingBalance: Money

    /// 기간 중 순입출금. 입금은 +, 출금은 −.
    public let netCashFlow: Money

    /// 0.12 == 12%.
    public let rate: Decimal

    // MARK: - Function

    public init(
        openingBalance: Money,
        closingBalance: Money,
        netCashFlow: Money,
        rate: Decimal
    ) {
        self.openingBalance = openingBalance
        self.closingBalance = closingBalance
        self.netCashFlow = netCashFlow
        self.rate = rate
    }
}

/// 연초(1/1) 대비 현재까지의 수익률을 계산한다.
///
/// `(기말자산 − 기초자산 − 순입출금) / 기초자산` — 입출금은 투자 성과가 아니므로 빼고 본다.
public protocol CalculateYTDReturnUseCaseProtocol: Sendable {
    /// 기준 삼을 연초 자산이 없거나 0이면 nil. 기록이 아직 없는 것은 실패가 아니므로
    /// 저장소 오류(throw)와 뭉개지 않고 값으로 구분한다.
    func execute(
        asOf date: Date,
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> YTDReturn?
}

public struct CalculateYTDReturnUseCase: CalculateYTDReturnUseCaseProtocol {
    // MARK: - Property

    private let snapshotRepository: any SnapshotRepositoryProtocol
    private let cashFlowRepository: any CashFlowRepositoryProtocol
    private let fetchNetWorthUseCase: any FetchNetWorthUseCaseProtocol
    private let calendar: Calendar

    // MARK: - Function

    public init(
        snapshotRepository: any SnapshotRepositoryProtocol,
        cashFlowRepository: any CashFlowRepositoryProtocol,
        fetchNetWorthUseCase: any FetchNetWorthUseCaseProtocol,
        calendar: Calendar = .current
    ) {
        self.snapshotRepository = snapshotRepository
        self.cashFlowRepository = cashFlowRepository
        self.fetchNetWorthUseCase = fetchNetWorthUseCase
        self.calendar = calendar
    }

    public func execute(
        asOf date: Date,
        baseCurrency: Currency,
        exchangeRate: ExchangeRate
    ) async throws -> YTDReturn? {
        let yearStart = try startOfYear(containing: date)
        let snapshots = try await snapshotRepository.fetch(from: yearStart, to: date)

        guard let opening = snapshots.first else { return nil }

        let closing = try await fetchNetWorthUseCase.execute(
            baseCurrency: baseCurrency,
            exchangeRate: exchangeRate
        ).total

        let events = try await cashFlowRepository.fetch(from: yearStart, to: date)
        let netCashFlow = events.reduce(Decimal.zero) {
            $0 + exchangeRate.convert($1.signedMoney, to: baseCurrency).amount
        }

        let openingBalance = opening.total(in: baseCurrency)
        guard
            let rate = Self.rate(
                opening: openingBalance.amount,
                closing: closing.amount,
                netCashFlow: netCashFlow
            )
        else { return nil }

        return YTDReturn(
            openingBalance: openingBalance,
            closingBalance: closing,
            netCashFlow: Money(amount: netCashFlow, currency: baseCurrency),
            rate: rate
        )
    }

    /// 입출금을 제외한 수익률. 기초자산이 0 이면 나눌 수 없어 아직 낼 수 없다는 뜻으로 nil 이다.
    static func rate(opening: Decimal, closing: Decimal, netCashFlow: Decimal) -> Decimal? {
        guard opening > 0 else { return nil }
        return (closing - opening - netCashFlow) / opening
    }

    private func startOfYear(containing date: Date) throws -> Date {
        let components = calendar.dateComponents([.year], from: date)
        guard let yearStart = calendar.date(from: components) else {
            throw AppError.validation("기간을 계산할 수 없어요.")
        }
        return yearStart
    }
}
