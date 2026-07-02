import napkin

// Viewless napkin: the plain Router base class, no ViewControllable.
@MainActor
final class AnnouncementsNapkinRouter:
    Router<AnnouncementsNapkinInteractor>,
    AnnouncementsNapkinRouting
{}
