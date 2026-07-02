import napkin

protocol PitBoardNapkinDependency: Dependency {
    var pitService: PitService { get }
    var specialsService: SpecialsService { get }
}

final class PitBoardNapkinComponent: Component<PitBoardNapkinDependency>, @unchecked Sendable {

    var pitService: PitService { dependency.pitService }
    var specialsService: SpecialsService { dependency.specialsService }
}

protocol PitBoardNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: PitBoardNapkinListener) async -> PitBoardNapkinRouting
}

final class PitBoardNapkinBuilder: Builder<PitBoardNapkinDependency>, PitBoardNapkinBuildable, @unchecked Sendable {

    override init(dependency: PitBoardNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: PitBoardNapkinListener) async -> PitBoardNapkinRouting {
        let component = PitBoardNapkinComponent(dependency: dependency)
        // Acyclic construction: VC first, then the presenter that needs it,
        // then bind so the view reads the presenter's @Observable state.
        let viewController = PitBoardNapkinViewController()
        let presenter = PitBoardNapkinPresenter(viewController: viewController)
        viewController.bind(presenter: presenter)
        let interactor = PitBoardNapkinInteractor(
            presenter: presenter,
            pitService: component.pitService,
            specialsService: component.specialsService
        )
        let router = PitBoardNapkinRouter(interactor: interactor, viewController: viewController)
        await interactor.wire(router: router, listener: listener)
        return router
    }
}
