//
//  Copyright (c) 2017. Uber Technologies
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import XCTest
import Combine
@testable import napkin

final class RouterTests: XCTestCase {

    private var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = []
        LeakDetector.disableLeakDetectorOverride = true
    }

    override func tearDown() {
        cancellables = nil
        LeakDetector.disableLeakDetectorOverride = false
        super.tearDown()
    }

    // MARK: - Initialization Tests

    func testRouter_initialization_hasNoChildren() {
        let interactor = TestInteractor()
        let router = TestRouter(interactor: interactor)

        XCTAssertTrue(router.children.isEmpty)
    }

    func testRouter_initialization_setsInteractor() {
        let interactor = TestInteractor()
        let router = TestRouter(interactor: interactor)

        XCTAssertTrue(router.interactor === interactor)
    }

    func testRouter_initialization_setsInteractable() {
        let interactor = TestInteractor()
        let router = TestRouter(interactor: interactor)

        XCTAssertTrue(router.interactable === interactor)
    }

    // MARK: - Load Tests

    func testRouter_load_callsDidLoad() {
        let interactor = TestInteractor()
        let router = TestRouter(interactor: interactor)

        router.load()

        XCTAssertTrue(router.didLoadCalled)
    }

    func testRouter_load_emitsDidLoadOnLifecycle() {
        let interactor = TestInteractor()
        let router = TestRouter(interactor: interactor)
        let expectation = expectation(description: "Lifecycle emits didLoad")
        var receivedEvent: RouterLifecycle?

        router.lifecycle
            .sink { event in
                receivedEvent = event
                expectation.fulfill()
            }
            .store(in: &cancellables)

        router.load()

        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedEvent, .didLoad)
    }

    func testRouter_loadCalledTwice_callsDidLoadOnlyOnce() {
        let interactor = TestInteractor()
        let router = TestRouter(interactor: interactor)

        router.load()
        router.didLoadCalled = false
        router.load()

        XCTAssertFalse(router.didLoadCalled)
    }

    // MARK: - Child Attachment Tests

    func testRouter_attachChild_addsToChildren() {
        let parentInteractor = TestInteractor()
        let parentRouter = TestRouter(interactor: parentInteractor)

        let childInteractor = TestInteractor()
        let childRouter = TestRouter(interactor: childInteractor)

        parentRouter.attachChild(childRouter)

        XCTAssertEqual(parentRouter.children.count, 1)
        XCTAssertTrue(parentRouter.children.first === childRouter)
    }

    func testRouter_attachChild_activatesChildInteractor() {
        let parentInteractor = TestInteractor()
        let parentRouter = TestRouter(interactor: parentInteractor)

        let childInteractor = TestInteractor()
        let childRouter = TestRouter(interactor: childInteractor)

        parentRouter.attachChild(childRouter)

        XCTAssertTrue(childInteractor.isActive)
    }

    func testRouter_attachChild_loadsChildRouter() {
        let parentInteractor = TestInteractor()
        let parentRouter = TestRouter(interactor: parentInteractor)

        let childInteractor = TestInteractor()
        let childRouter = TestRouter(interactor: childInteractor)

        parentRouter.attachChild(childRouter)

        XCTAssertTrue(childRouter.didLoadCalled)
    }

    func testRouter_attachMultipleChildren_addsAllToChildren() {
        let parentInteractor = TestInteractor()
        let parentRouter = TestRouter(interactor: parentInteractor)

        let child1 = TestRouter(interactor: TestInteractor())
        let child2 = TestRouter(interactor: TestInteractor())
        let child3 = TestRouter(interactor: TestInteractor())

        parentRouter.attachChild(child1)
        parentRouter.attachChild(child2)
        parentRouter.attachChild(child3)

        XCTAssertEqual(parentRouter.children.count, 3)
    }

    // MARK: - Child Detachment Tests

    func testRouter_detachChild_removesFromChildren() {
        let parentInteractor = TestInteractor()
        let parentRouter = TestRouter(interactor: parentInteractor)

        let childInteractor = TestInteractor()
        let childRouter = TestRouter(interactor: childInteractor)

        parentRouter.attachChild(childRouter)
        parentRouter.detachChild(childRouter)

        XCTAssertTrue(parentRouter.children.isEmpty)
    }

    func testRouter_detachChild_deactivatesChildInteractor() {
        let parentInteractor = TestInteractor()
        let parentRouter = TestRouter(interactor: parentInteractor)

        let childInteractor = TestInteractor()
        let childRouter = TestRouter(interactor: childInteractor)

        parentRouter.attachChild(childRouter)
        parentRouter.detachChild(childRouter)

        XCTAssertFalse(childInteractor.isActive)
    }

    func testRouter_detachSpecificChild_onlyRemovesThatChild() {
        let parentInteractor = TestInteractor()
        let parentRouter = TestRouter(interactor: parentInteractor)

        let child1 = TestRouter(interactor: TestInteractor())
        let child2 = TestRouter(interactor: TestInteractor())

        parentRouter.attachChild(child1)
        parentRouter.attachChild(child2)
        parentRouter.detachChild(child1)

        XCTAssertEqual(parentRouter.children.count, 1)
        XCTAssertTrue(parentRouter.children.first === child2)
    }

    // MARK: - Subtree Activation Tests

    func testRouter_parentActivation_activatesSubtree() {
        let parentInteractor = TestInteractor()
        let parentRouter = TestRouter(interactor: parentInteractor)
        parentRouter.load()

        let childInteractor = TestInteractor()
        let childRouter = TestRouter(interactor: childInteractor)

        let grandchildInteractor = TestInteractor()
        let grandchildRouter = TestRouter(interactor: grandchildInteractor)

        parentRouter.attachChild(childRouter)
        childRouter.attachChild(grandchildRouter)

        parentInteractor.activate()

        XCTAssertTrue(childInteractor.isActive)
        XCTAssertTrue(grandchildInteractor.isActive)
    }

    func testRouter_parentDeactivation_deactivatesSubtree() {
        let parentInteractor = TestInteractor()
        let parentRouter = TestRouter(interactor: parentInteractor)
        parentRouter.load()

        let childInteractor = TestInteractor()
        let childRouter = TestRouter(interactor: childInteractor)

        parentRouter.attachChild(childRouter)
        parentInteractor.activate()
        parentInteractor.deactivate()

        XCTAssertFalse(childInteractor.isActive)
    }
}

// MARK: - Test Doubles

private class TestInteractor: Interactor {
    var didBecomeActiveCalled = false
    var willResignActiveCalled = false

    override func didBecomeActive() {
        super.didBecomeActive()
        didBecomeActiveCalled = true
    }

    override func willResignActive() {
        super.willResignActive()
        willResignActiveCalled = true
    }
}

private class TestRouter: Router<TestInteractor> {
    var didLoadCalled = false

    override func didLoad() {
        super.didLoad()
        didLoadCalled = true
    }
}
