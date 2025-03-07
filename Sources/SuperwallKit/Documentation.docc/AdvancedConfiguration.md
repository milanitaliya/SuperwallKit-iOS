# Advanced Configuration

Use options and custom subscription-related logic for more control over the SDK.

## Overview

By default, Superwall handles all subscription-related logic. However, if you're using RevenueCat, or you just want more control, you can return a ``SuperwallKit/SubscriptionController`` in
 the delegate when configuring the SDK via
 ``Superwall/configure(apiKey:delegate:options:)-48l7e``. In addition, you can customise aspects of the SDK by passing in a ``SuperwallOptions`` object on configure.

## Creating a Subscription Controller

A subscription controller handles purchasing, restoring, and user subscription status via protocol methods that you implement. You return your subscription controller via a `subscriptionController()` method in the ``SuperwallDelegate``, which you pass in when configuring the SDK:

```swift
import SuperwallKit

final class SuperwallService {
  private static let apiKey = "MYAPIKEY" // Replace this with your API Key
  static let shared = SuperwallService()

  static func initialize() {
    Superwall.configure(
      apiKey: apiKey,
      delegate: shared
    )
  }
}

// MARK: - Superwall Delegate
extension SuperwallService: SuperwallDelegate {
  func subscriptionController() -> SubscriptionController {
    return self
  }
}

// MARK: - SubscriptionController
extension SuperwallService: SubscriptionController {
  // 1
  func purchase(product: SKProduct) async -> PurchaseResult {
    // TODO: Purchase the product here and return its result.
    return .cancelled
  }

  // 2
  func restorePurchases() async -> Bool {
    // TODO: Restore purchases and call completion block with boolean indicating
    // the success status of restoration.
    return false
  }

  // 3
  func isUserSubscribed() -> Bool {
    // TODO: Return boolean indicating the user's subscription status.
    // Ideally you will have a local state stored in UserDefaults
    // indicating subscription status that's synced with revenuecat.
    return false
  }
}
```

All methods of the ``SubscriptionController`` are mandatory and receive callbacks from the SDK in response to certain events that happen on the paywall. It is up to you to fill these methods with the appropriate code. Here's what each method is responsible for:

1. Purchasing a given product. In here, enter your code that you use to purchase a product. If you're using RevenueCat, you'll need to turn off StoreKit2 when initialising the SDK. Then, handle the result by returning a `PurchaseResult`. This is an enum that contains the following cases, all of which must be handled. Check out our example apps for further information about handling these cases:
    - `.cancelled`: The purchase was cancelled.
    - `.purchased`: The product was purchased.
    - `.pending`: The purchase is pending and requires action from the developer.
    - `.failed(Error)`: The purchase failed for a reason other than the user cancelling or the payment pending.

2. Restoring purchases. Make sure to call the completion block after you attempt to restore purchases to let the SDK know whether the restoration was successful or not.

3. Telling the SDK whether the user has an active subscription. Replace this with a boolean indicating the user's subscription status. Ideally you will have a local state stored in UserDefaults indicating subscription status that's synced with the actual status.

## Passing in Superwall Options

When configuring the SDK you can pass in options that configure Superwall, the paywall presentation, and its appearance. Take a look at ``SuperwallOptions`` for all possible values.
