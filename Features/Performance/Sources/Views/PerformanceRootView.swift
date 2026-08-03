//
//  PerformanceRootView.swift
//  PerformanceFeature
//
//  Created by euijjang97 on 7/31/26.
//

import HannunCore
import SwiftUI

/// 투자 성과 탭 루트 (PM-1 ~ PM-4).
public struct PerformanceRootView: View {

    // MARK: - Property

    @Environment(DIContainer.self) private var container

    // MARK: - Body

    public init() {}

    public var body: some View {
        PerformanceScreen(container: container)
    }
}

/// ViewModel 을 소유하는 실제 화면.
///
/// 루트와 나눠 놓은 이유는 컨테이너 주입 시점 때문이다. 앱 셸이 `PerformanceRootView()` 를
/// 인자 없이 만들어서 `init` 에서는 컨테이너를 볼 수 없고, `@Environment` 는 body 에서야 읽힌다.
/// 그 값을 `init` 으로 받는 자식을 하나 두면 ViewModel 을 `@State` 로 한 번만 만들 수 있다.
private struct PerformanceScreen: View {

    // MARK: - Property

    @State private var viewModel: PerformanceViewModel

    // MARK: - Body

    init(container: DIContainer) {
        _viewModel = State(initialValue: PerformanceViewModel(container: container))
    }

    var body: some View {
        NavigationStack {
            PerformanceContentView(viewModel: viewModel)
                .navigationTitle(Constants.navigationTitle)
                // 벤치마크는 저빈도라 액세서리가 아니라 툴바 아이콘 하나로 내렸다 (문서 §7).
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            viewModel.isBenchmarkPickerPresented = true
                        } label: {
                            Image(systemName: Constants.benchmarkToolbarSymbolName)
                        }
                        .accessibilityLabel(Constants.benchmarkToolbarAccessibilityLabel)
                    }
                }
        }
        // 액세서리는 화면이 아니라 탭에 속하므로 루트에만 등록한다 (UI 스펙 §3.1).
        .tabAccessory(.performance) {
            PerformanceAccessory(viewModel: self.viewModel)
        }
        // 시트도 탭 루트가 띄운다 — 여는 주체가 액세서리·툴바라 화면에 붙이면 화면이 바뀔 때
        // 시트까지 함께 사라진다 (디자인 문서 §7).
        .sheet(isPresented: $viewModel.isPeriodPickerPresented) {
            PeriodPickerSheet(viewModel: self.viewModel)
        }
        .sheet(isPresented: $viewModel.isBenchmarkPickerPresented) {
            BenchmarkPickerSheet(viewModel: self.viewModel)
        }
        .task { await viewModel.loadIfNeeded() }
    }
}

fileprivate enum Constants {
    static let navigationTitle = "투자 성과"
    static let benchmarkToolbarSymbolName = "chart.line.uptrend.xyaxis"
    static let benchmarkToolbarAccessibilityLabel = "벤치마크 비교"
}
