//
//  DonationOptionsSheet.swift
//  TaiwanEEW
//

import SwiftUI
import RevenueCat

struct DonationOption {
    let id: String
    let title: String
    let subtitle: String
    let fallbackPrice: String
    let duration: String?
    let iconName: String
    let iconColor: Color
    let isExternal: Bool
}

struct DonationOptionsSheet: View {
    @StateObject private var purchaseManager = PurchaseManager()
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    @State private var selectedOptionId: String? = "monthly_120" // Default selection
    @State private var restoreAlertTitle = ""
    @State private var restoreAlertMessage = ""
    @State private var showRestoreAlert = false

    let options: [DonationOption] = [
        // Subscriptions
        DonationOption(id: "monthly_60", title: "每月一份鼓勵", subtitle: "感謝您補貼營運費用🥹", fallbackPrice: "NT$60", duration: "/ 月", iconName: "gift.fill", iconColor: Color.pink, isExternal: false),
        DonationOption(id: "monthly_120", title: "雙倍鼓勵", subtitle: "這個 App 又夠讚的啦！！！！", fallbackPrice: "NT$120", duration: "/ 月", iconName: "heart.fill", iconColor: Color.red, isExternal: false),

        // One-time
        DonationOption(id: "onetime_30", title: "中熱美", subtitle: "賦予半天的生命", fallbackPrice: "NT$30", duration: "一次性", iconName: "cup.and.saucer.fill", iconColor: Color.brown, isExternal: false),
        DonationOption(id: "onetime_60", title: "「給我一對翅膀～」", subtitle: "只有我發現能量飲漲價了嗎", fallbackPrice: "NT$60", duration: "一次性", iconName: "bolt.fill", iconColor: Color.yellow, isExternal: false),
        DonationOption(id: "onetime_150", title: "一份高蛋白便當", subtitle: "修復我的腦細胞", fallbackPrice: "NT$150", duration: "一次性", iconName: "takeoutbag.and.cup.and.straw.fill", iconColor: Color.orange, isExternal: false),
        DonationOption(id: "onetime_590", title: "超級支持者", subtitle: "真的非常感謝您的支持！", fallbackPrice: "NT$590", duration: "一次性", iconName: "trophy.fill", iconColor: Color.cyan, isExternal: false),
        DonationOption(id: "onetime_1550", title: "乾爹 / 乾媽", subtitle: "最高級別的鼎力相助", fallbackPrice: "NT$1550", duration: "一次性", iconName: "crown.fill", iconColor: Color.purple, isExternal: false),

        // ECPay
        DonationOption(id: "ecpay", title: "其他金額／支付方式", subtitle: "超商代碼、ATM", fallbackPrice: "自訂", duration: nil, iconName: "creditcard.fill", iconColor: Color.gray, isExternal: true)
    ]

    var selectedOption: DonationOption? {
        options.first(where: { $0.id == selectedOptionId })
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding()
            Spacer()
        }
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("支持台灣地震速報")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text("您的慷慨解囊將用於升級設備與維持伺服器營運。您可以選擇定期定額，或是一次性的贊助。")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineSpacing(4)
        }
        .padding(.horizontal)
        .padding(.bottom, 10)
    }

    private var monthlySubscriptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("每月定期定額")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ForEach(options.filter { $0.id.hasPrefix("monthly") }, id: \.id) { option in
                DonationOptionRow(
                    option: option,
                    localizedPrice: purchaseManager.packages.first(where: { $0.identifier == option.id })?.localizedPriceString,
                    isSelected: selectedOptionId == option.id,
                    action: { select(option) }
                )
            }
            .padding(.horizontal)
        }
    }

    private var oneTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("一次性贊助")
                .font(.headline)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            ForEach(options.filter { $0.id.hasPrefix("onetime") || $0.id == "ecpay" }, id: \.id) { option in
                DonationOptionRow(
                    option: option,
                    localizedPrice: purchaseManager.packages.first(where: { $0.identifier == option.id })?.localizedPriceString,
                    isSelected: selectedOptionId == option.id,
                    action: { select(option) }
                )
            }
            .padding(.horizontal)
        }
    }

    private var continueButton: some View {
        let isExternal = selectedOption?.isExternal == true

        return Button(action: {
            handleContinue()
        }) {
            Text(isExternal ? "前往 ECPay 付款" : "確認付款")
                .font(.headline)
                .foregroundColor(colorScheme == .dark ? .black : .white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(UIColor { $0.userInterfaceStyle == .dark ? .white : .black }))
                .cornerRadius(12)
        }
        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private var paymentInfoText: some View {
        if let selected = selectedOption, !selected.isExternal {
            if selected.duration == "/ 月" {
                // Omit the amount rather than assert a possibly-wrong TWD fallback when the
                // localized price has not loaded.
                let localized = purchaseManager.packages.first(where: { $0.identifier == selected.id })?.localizedPriceString
                Text(localized.map { "將自動每月扣款 \($0) 直到取消" } ?? "將自動每月扣款，直到取消")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("此為一次性付款，不會自動扣款")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var footerLinks: some View {
        HStack(spacing: 30) {
            Button("恢復購買") {
                purchaseManager.restorePurchases()
            }
            .font(.caption.bold())
            .foregroundColor(.secondary)

            Link("服務條款", destination: AppLinks.termsOfService)
                .font(.caption.bold())
                .foregroundColor(.secondary)

            Link("隱私權政策", destination: AppLinks.privacyPolicy)
                .font(.caption.bold())
                .foregroundColor(.secondary)
        }
        .padding(.top, 4)
    }

    private var footerView: some View {
        VStack(spacing: 16) {
            continueButton
            paymentInfoText
            footerLinks
        }
        .padding(20)
        .background(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
    }

    @ViewBuilder
    private var loadingOverlay: some View {
        if purchaseManager.isFetching {
            Color.black.opacity(0.2).ignoresSafeArea()
            ProgressView()
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(10)
        }
    }

    @ViewBuilder
    private var successOverlay: some View {
        if purchaseManager.purchaseSucceeded {
            ThankYouOverlay {
                dismiss()
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    titleSection
                    monthlySubscriptionsSection
                    oneTimeSection
                    Spacer(minLength: 40)
                }
            }

            footerView
        }
        .background(Color(UIColor.secondarySystemBackground).ignoresSafeArea())
        .overlay(loadingOverlay)
        .overlay(successOverlay)
        .alert(restoreAlertTitle, isPresented: $showRestoreAlert) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(restoreAlertMessage)
        }
        .onChange(of: purchaseManager.restoreResult) { result in
            guard let result = result else { return }
            switch result {
            case .success:
                restoreAlertTitle = "恢復成功"
                restoreAlertMessage = "您的購買紀錄已成功恢復。"
            case .noActiveSubscriptions:
                restoreAlertTitle = "找不到購買紀錄"
                restoreAlertMessage = "目前帳號沒有可恢復的訂閱或購買紀錄。"
            case .failed(let message):
                restoreAlertTitle = "恢復失敗"
                restoreAlertMessage = message
            }
            showRestoreAlert = true
            purchaseManager.restoreResult = nil
        }
    }

    private func select(_ option: DonationOption) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            selectedOptionId = option.id
        }
    }

    private func handleContinue() {
        guard let selectedId = selectedOptionId else { return }

        if selectedId == "ecpay" {
            AnalysicsManager.shared.logEvent(name: "ecpay_redirect")
            UIApplication.shared.open(AppLinks.ecPayOneTime)
        } else {
            if let package = purchaseManager.packages.first(where: { $0.identifier == selectedId }) {
                let price = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue
                let currency = package.storeProduct.currencyCode ?? "TWD"
                AnalysicsManager.shared.logEvent(name: "begin_checkout", params: [
                    "value": price,
                    "currency": currency,
                    "items": [[
                        "item_id": package.identifier,
                        "item_name": package.identifier,
                        "price": price,
                        "quantity": 1
                    ]]
                ])
                purchaseManager.purchase(package)
            } else {
                print("Package \(selectedId) not found in loaded offerings.")
            }
        }
    }
}

struct DonationOptionRow: View {
    let option: DonationOption
    let localizedPrice: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    option.iconColor
                    Image(systemName: option.iconName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(option.title)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)

                    Text(option.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    // For the external ECPay option, fallbackPrice is a label ("自訂"), so keep
                    // it. For StoreKit products, never fall back to a hardcoded TWD amount - a
                    // non-TW storefront is charged in its own currency, so showing "NT$60" there
                    // is wrong. Show a neutral placeholder until RevenueCat's localized price loads.
                    Text(localizedPrice ?? (option.isExternal ? option.fallbackPrice : "—"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)

                    if let duration = option.duration {
                        Text(duration)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(UIColor.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? Color.blue.opacity(0.15) : Color.black.opacity(0.03), radius: isSelected ? 8 : 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct ThankYouOverlay: View {
    let onDismiss: () -> Void

    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var heartScale: CGFloat = 0.3
    @State private var particles: [ThankYouParticle] = ThankYouParticle.generate()

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
                .onTapGesture { animateDismiss() }

            ForEach(particles) { particle in
                Image(systemName: particle.symbol)
                    .font(.system(size: particle.size))
                    .foregroundColor(particle.color)
                    .position(particle.position)
                    .opacity(opacity)
                    .scaleEffect(opacity > 0 ? 1 : 0.1)
                    .animation(.spring(response: 0.6, dampingFraction: 0.5).delay(particle.delay), value: opacity)
            }

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.pink.opacity(0.15))
                        .frame(width: 100, height: 100)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.pink)
                        .scaleEffect(heartScale)
                        .animation(.spring(response: 0.5, dampingFraction: 0.4).delay(0.1), value: heartScale)
                }

                VStack(spacing: 8) {
                    Text("感謝您的支持！")
                        .font(.system(size: 26, weight: .bold))
                    Text("收到您的贊助了！您的支持讓這個 App 可以繼續運作，真的非常感謝 🙏")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Button(action: { animateDismiss() }) {
                    Text("關閉")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.pink)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding(32)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 10)
            .padding(.horizontal, 40)
            .scaleEffect(scale)
            .opacity(opacity)
            .animation(.spring(response: 0.5, dampingFraction: 0.65), value: scale)
            .animation(.easeOut(duration: 0.3), value: opacity)
        }
        .onAppear {
            withAnimation { opacity = 1; scale = 1; heartScale = 1 }
        }
    }

    private func animateDismiss() {
        withAnimation(.easeIn(duration: 0.25)) {
            opacity = 0
            scale = 0.85
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

struct ThankYouParticle: Identifiable {
    let id = UUID()
    let symbol: String
    let size: CGFloat
    let color: Color
    let position: CGPoint
    let delay: Double

    static func generate() -> [ThankYouParticle] {
        let symbols = ["heart.fill", "star.fill", "sparkles", "heart.fill", "star.fill", "suit.heart.fill", "star.circle.fill", "heart.circle.fill"]
        let colors: [Color] = [.pink, .red, .orange, .yellow, .purple, .cyan, .mint]
        let screenW = UIScreen.main.bounds.width
        let screenH = UIScreen.main.bounds.height

        let cols = 7
        let rows = 9
        return (0..<(cols * rows)).map { i in
            let col = i % cols
            let row = i / cols
            let cellW = screenW / CGFloat(cols)
            let cellH = screenH / CGFloat(rows)
            let baseX = cellW * CGFloat(col) + cellW * 0.1
            let baseY = cellH * CGFloat(row) + cellH * 0.1
            let jitterX = CGFloat.random(in: 0...(cellW * 0.8))
            let jitterY = CGFloat.random(in: 0...(cellH * 0.8))
            return ThankYouParticle(
                symbol: symbols[i % symbols.count],
                size: CGFloat.random(in: 10...26),
                color: colors[i % colors.count].opacity(Double.random(in: 0.5...1.0)),
                position: CGPoint(x: baseX + jitterX, y: baseY + jitterY),
                delay: Double(i) * 0.015
            )
        }
    }
}

struct DonationOptionsSheetWrapper: View {
    var body: some View {
        if #available(iOS 16.0, *) {
            DonationOptionsSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            DonationOptionsSheet()
        }
    }
}

#Preview {
    DonationOptionsSheetWrapper()
}
