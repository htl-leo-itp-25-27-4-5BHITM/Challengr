import XCTest
@testable import Challengr

/// Login bleibt nach dem Beenden der App: Tokens im Schlüsselbund.
final class TokenStoreTests: XCTestCase {
    override func tearDown() { TokenStore.clear() }

    func testSaveLoadOverwriteAndClear() {
        TokenStore.clear()
        XCTAssertNil(TokenStore.load(TokenStore.refreshTokenKey))
        TokenStore.save("eins", for: TokenStore.refreshTokenKey)
        TokenStore.save("zwei", for: TokenStore.refreshTokenKey)
        TokenStore.save("id", for: TokenStore.idTokenKey)
        XCTAssertEqual(TokenStore.load(TokenStore.refreshTokenKey), "zwei", "überschreibt statt doppelt")
        TokenStore.clear()
        XCTAssertNil(TokenStore.load(TokenStore.refreshTokenKey))
        XCTAssertNil(TokenStore.load(TokenStore.idTokenKey))
    }
}
