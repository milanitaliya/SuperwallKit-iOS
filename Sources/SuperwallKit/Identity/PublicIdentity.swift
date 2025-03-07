//
//  File.swift
//  
//
//  Created by Yusuf Tör on 23/09/2022.
//

import Foundation

// MARK: - Log In
public extension Superwall {
  /// Logs in a user with their `userId` to retrieve paywalls that they've been assigned to.
  ///
  /// This links a `userId` to Superwall's automatically generated alias. Call this once after you've retrieved a userId.
  ///
  /// The user will stay logged in until you call ``SuperwallKit/Superwall/logOut()``. If you call this while they're already logged in, it will throw an error of type ``IdentityError``.
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Throws: An error of type ``IdentityError``.
  @objc func logIn(userId: String) async throws {
    try await dependencyContainer.identityManager.logIn(userId: userId)
  }

  /// Logs in a user with their `userId` to retrieve paywalls that they've been assigned to.
  ///
  /// This links a `userId` to Superwall's automatically generated alias. Call this as soon
  /// as you have a userId. If a user with a different id was previously identified, calling this
  /// will automatically call ``reset()``
  ///  - Parameters:
  ///   - userId: Your user's unique identifier, as defined by your backend system.
  ///   - completion: A completion block that accepts a `Result` enum. Its success value is
  ///   the shared Superwall instance, and its failure error is of type ``IdentityError``.
  func logIn(
    userId: String,
    completion: ((Result<Void, IdentityError>) -> Void)?
  ) {
    Task {
      do {
        try await logIn(userId: userId)
        await MainActor.run {
          completion?(.success(()))
        }
      } catch let error as IdentityError {
        await MainActor.run {
          completion?(.failure(error))
        }
      }
    }
  }
}


// MARK: - Create Account
public extension Superwall {
  /// Creates an account with Superwall. This links a `userId` to Superwall's automatically generated alias.
  ///
  /// Call this as soon as you have a `userId`. If you are logging in an existing user, you should use
  /// ``Superwall/logIn(userId:)`` instead, as that will retrieve their assigned paywalls.
  ///
  ///  - Parameter userId: Your user's unique identifier, as defined by your backend system.
  ///  - Throws: An error of type ``IdentityError``.
  @objc func createAccount(userId: String) throws {
    try dependencyContainer.identityManager.createAccount(userId: userId)
  }
}

// MARK: - Log Out
public extension Superwall {
  /// Logs out the user. This calls ``reset()``, which resets on-device paywall
  /// assignments and the `userId` stored by Superwall.
  ///
  /// You must call this method before attempting to log in a new user.
  /// If a user isn't already logged in before calling this method, an error will be thrown.
  ///
  ///  - Throws: An error of type ``LogoutError``.
  @objc func logOut() async throws {
    try await dependencyContainer.identityManager.logOut()
  }

  /// Logs out the user. This calls ``reset()``, which resets on-device paywall
  /// assignments and the `userId` stored by Superwall.
  ///
  /// You must call this method before attempting to log in a new user.
  /// If a user isn't already logged in before calling this method, an error will be thrown.
  ///
  /// - Parameters:
  ///   - completion: A completion block that accepts a `Result` object.
  ///   The `Result`'s success value is `Void` and failure error is of type ``LogoutError``.
  func logOut(completion: ((Result<Void, LogoutError>) -> Void)? = nil) {
    Task {
      do {
        try await logOut()
        await MainActor.run {
          completion?(.success(()))
        }
      } catch let error as LogoutError {
        await MainActor.run {
          completion?(.failure(error))
        }
      }
    }
  }
}

// MARK: - Reset
public extension Superwall {
  /// Resets the `userId`, on-device paywall assignments, and data stored
  /// by Superwall.
  @objc func reset() async {
    presentationItems.reset()
    dependencyContainer.identityManager.reset()
    dependencyContainer.storage.reset()
    await dependencyContainer.paywallManager.resetCache()
    dependencyContainer.configManager.reset()
    dependencyContainer.identityManager.didSetIdentity()
  }

  /// Asynchronously resets the `userId` and data stored by Superwall.
  ///
  /// - Parameters:
  ///   - completion: A completion block that is called when reset has completed.
  func reset(completion: (() -> Void)? = nil) {
    Task {
      await reset()
      await MainActor.run {
        completion?()
      }
    }
  }
}
