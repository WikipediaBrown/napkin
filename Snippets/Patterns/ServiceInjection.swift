// snippet.hide
import napkin
// snippet.show

// Service injection via the dependency tree. The feature declares what it
// needs from above; the parent's component satisfies it via extension
// conformance. Compile-time checked — no runtime container, no annotation
// processor.

protocol AuthService: Sendable {
    func login() async throws -> String
}

// 1. The feature's Dependency protocol lists what it requires.
protocol HomeNapkinDependency: Dependency {
    var authService: AuthService { get }
}

// 2. The feature's Component reads from the dependency.
final class HomeNapkinComponent: Component<HomeNapkinDependency>, @unchecked Sendable {
    var authService: AuthService { dependency.authService }
}

// 3. The parent's Component conforms to the feature's Dependency by extension.
//    The root component owns the actual service instance.
protocol AppDependency: Dependency {}

final class AppComponent: Component<EmptyDependency>, AppDependency, @unchecked Sendable {
    let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
        super.init(dependency: EmptyComponent())
    }
}

// Connect the two: AppComponent satisfies HomeNapkinDependency.
extension AppComponent: HomeNapkinDependency {}
