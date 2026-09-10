import Foundation
import StoreKit

enum ProPurchaseResult {
    case purchased
    case pending
    case cancelled
}

enum StoreKitServiceError: LocalizedError {
    case productUnavailable([String])
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .productUnavailable:
            L10n.t("暂时无法加载会员商品，请稍后再试。")
        case .unverifiedTransaction:
            L10n.t("购买校验未通过，请稍后重试或联系支持。")
        }
    }
}

@MainActor
final class StoreKitService {
    static let proProductID = "payjoy.pro.lifetime"
    static let compatibleProProductIDs = [
        proProductID,
        "app.payjoy.kaixin.pro.lifetime"
    ]

    private var proProduct: Product?

    func loadProProduct() async throws -> Product {
        if let proProduct {
            return proProduct
        }

        let products = try await Product.products(for: [Self.proProductID])
        guard let product = products.first(where: { $0.id == Self.proProductID }) else {
            throw StoreKitServiceError.productUnavailable([Self.proProductID])
        }

        proProduct = product
        return product
    }

    func purchasePro() async throws -> ProPurchaseResult {
        let product = try await loadProProduct()
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try verified(verification)
            await transaction.finish()
            return .purchased
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .cancelled
        }
    }

    func restorePurchases() async throws {
        try await AppStore.sync()
    }

    func finishUpdatedTransaction(_ verification: VerificationResult<Transaction>) async throws {
        let transaction = try verified(verification)
        await transaction.finish()
    }

    func hasProEntitlement() async -> Bool {
        for await entitlement in Transaction.currentEntitlements {
            guard let transaction = try? verified(entitlement),
                  Self.compatibleProProductIDs.contains(transaction.productID),
                  transaction.revocationDate == nil else {
                continue
            }

            return true
        }

        return false
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw StoreKitServiceError.unverifiedTransaction
        }
    }
}
