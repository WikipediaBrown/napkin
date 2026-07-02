import napkin

protocol AnnouncementsNapkinDependency: Dependency {
    var pitService: PitService { get }
}

final class AnnouncementsNapkinComponent: Component<AnnouncementsNapkinDependency>, @unchecked Sendable {

    var pitService: PitService { dependency.pitService }
}

protocol AnnouncementsNapkinBuildable: Buildable {
    @MainActor func build(withListener listener: AnnouncementsNapkinListener) async -> AnnouncementsNapkinRouting
}

final class AnnouncementsNapkinBuilder: Builder<AnnouncementsNapkinDependency>, AnnouncementsNapkinBuildable, @unchecked Sendable {

    override init(dependency: AnnouncementsNapkinDependency) {
        super.init(dependency: dependency)
    }

    @MainActor
    func build(withListener listener: AnnouncementsNapkinListener) async -> AnnouncementsNapkinRouting {
        let component = AnnouncementsNapkinComponent(dependency: dependency)
        let interactor = AnnouncementsNapkinInteractor(pitService: component.pitService)
        let router = AnnouncementsNapkinRouter(interactor: interactor)
        await interactor.wire(router: router, listener: listener)
        return router
    }
}
