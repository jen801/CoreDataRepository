// CRUDRepositoryTests.swift
// CoreDataRepository
//
//
// MIT License
//
// Copyright © 2022 Andrew Roan

import Combine
import CoreData
import CoreDataRepository
import CustomDump
import XCTest

final class CRUDRepositoryTests: CoreDataXCTestCase {
    static var allTests = [
        ("testCreateSuccess", testCreateSuccess),
        ("testReadSuccess", testReadSuccess),
        ("testReadFailure", testReadFailure),
        ("testUpdateSuccess", testUpdateSuccess),
        ("testUpdateFailure", testUpdateFailure),
        ("testDeleteSuccess", testDeleteSuccess),
        ("testDeleteFailure", testDeleteFailure),
        ("testReadSubscriptionSuccess", testReadSubscriptionSuccess),
    ]

    var _repository: CoreDataRepository?
    var repository: CoreDataRepository { _repository! }

    override func setUp() {
        super.setUp()
        _repository = CoreDataRepository(context: viewContext)
    }

    override func tearDown() {
        super.tearDown()
        _repository = nil
    }

    func testCreateSuccess() throws {
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try? viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")

        let exp = expectation(description: "Create a RepoMovie in CoreData")
        var movie = Movie(id: UUID(), title: "Create Success", releaseDate: Date(), boxOffice: 100)
        repository.create(movie).subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Received failure from CRUDRepository.create")
                        exp.fulfill()
                    }
                },
                receiveValue: { _resultMovie in
                    var resultMovie = _resultMovie
                    XCTAssertNotNil(resultMovie.url)
                    resultMovie.url = nil
                    let diff = CustomDump.diff(resultMovie, movie)
                    XCTAssertNil(diff, "Success response should match local object but found diff \(diff ?? "").")
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)
        let all = ((try? viewContext.fetch(RepoMovie.fetchRequest())) ?? []).map(\.asUnmanaged)
        XCTAssert(
            all.count == 1,
            "There should be only one CoreData object after creating one, but found \(all.count)."
        )
        let fetchedMovie = try XCTUnwrap(all.first)
        XCTAssert(fetchedMovie.url != nil, "CoreData object should have NSManagedObjectID")
        movie.url = fetchedMovie.url
        let diff = CustomDump.diff(fetchedMovie, movie)
        XCTAssertNil(diff, "CoreData object should match the one created but found diff \(diff ?? "").")
    }

    func testCreateAsyncSuccess() async throws {
        let movie = Movie(id: UUID(), title: "Create Success", releaseDate: Date(), boxOffice: 100)
        let result: Result<Movie, CoreDataRepositoryError> = await repository.create(movie)
        guard case var .success(resultMovie) = result else {
            XCTFail("Not expecting a failed result")
            return
        }
        
        XCTAssertNotNil(resultMovie.url)
        resultMovie.url = nil
        let diff = CustomDump.diff(resultMovie, movie)
        XCTAssertNil(diff)
    }

    func testReadSuccess() throws {
        var movie = Movie(id: UUID(), title: "Read Success", releaseDate: Date(), boxOffice: 100)
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try? viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")
        let repoMovie = movie.asRepoManaged(in: viewContext)
        try? viewContext.save()
        movie.url = repoMovie.objectID.uriRepresentation()
        let countAfterCreate = try? viewContext.count(for: RepoMovie.fetchRequest())
        XCTAssert(countAfterCreate == 1, "Count of objects in CoreData should be 1 for read test.")

        let exp = expectation(description: "Read a RepoMovie in CoreData")
        let result: AnyPublisher<Movie, CoreDataRepositoryError> = repository.read(try XCTUnwrap(movie.url))
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Received failure from CRUDRepository.read")
                        exp.fulfill()
                    }
                },
                receiveValue: { resultMovie in
                    let diff = CustomDump.diff(resultMovie, movie)
                    XCTAssertNil(diff, "Success response should match local object, but found diff \(diff ?? "").")
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)
    }

    func testReadAsyncSuccess() async throws {
        let movie = Movie(id: UUID(), title: "Read Success", releaseDate: Date(), boxOffice: 100)
        let createdMovie: Movie = try await viewContext.perform(schedule: .immediate, {
            let object = RepoMovie(context: self.viewContext)
            object.create(from: movie)
            try self.viewContext.save()
            return object.asUnmanaged
        })
        
        let result: Result<Movie, CoreDataRepositoryError> = await repository.read(try XCTUnwrap(createdMovie.url))

        guard case var .success(resultMovie) = result else {
            XCTFail("Not expecting a failed result")
            return
        }
        
        XCTAssertNotNil(resultMovie.url)
        resultMovie.url = nil
        let diff = CustomDump.diff(resultMovie, movie)
        XCTAssertNil(diff)
    }

    func testReadFailure() throws {
        var movie = Movie(id: UUID(), title: "Read Failure", releaseDate: Date(), boxOffice: 100)
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try? viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")
        let repoMovie = movie.asRepoManaged(in: viewContext)
        try? viewContext.save()
        movie.url = repoMovie.objectID.uriRepresentation()
        let countAfterCreate = try? viewContext.count(for: RepoMovie.fetchRequest())
        XCTAssert(countAfterCreate == 1, "Count of objects in CoreData should be 1 for read test.")

        viewContext.delete(repoMovie)
        try? viewContext.save()

        let exp = expectation(description: "Fail to read a RepoMovie in CoreData")
        let result: AnyPublisher<Movie, CoreDataRepositoryError> = repository.read(try XCTUnwrap(movie.url))
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        XCTFail("Not expected to successfully finish.")
                    case .failure:
                        exp.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Not expected to receive a value for CRUDRepository.read")
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)
    }

    func testReadAsyncFailure() async throws {
        let movie = Movie(id: UUID(), title: "Read Failure", releaseDate: Date(), boxOffice: 100)
        let createdMovie: Movie = try await viewContext.perform {
            let object = RepoMovie(context: self.viewContext)
            object.create(from: movie)
            try self.viewContext.save()
            return object.asUnmanaged
        }
        _ = try await viewContext.perform {
            let objectID = self.viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: try XCTUnwrap(createdMovie.url))
            let object = try self.viewContext.existingObject(with: try XCTUnwrap(objectID))
            self.viewContext.delete(object)
            try self.viewContext.save()
        }
        
        let result: Result<Movie, CoreDataRepositoryError> = await repository.read(try XCTUnwrap(createdMovie.url))

        switch result {
        case .success:
            XCTFail("Not expecting a successful result")
        case .failure:
            XCTAssert(true)
        }
    }

    func testUpdateSuccess() throws {
        var movie = Movie(id: UUID(), title: "Update Success", releaseDate: Date(), boxOffice: 100)
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")
        let repoMovie = movie.asRepoManaged(in: viewContext)
        try viewContext.save()
        movie.url = repoMovie.objectID.uriRepresentation()
        let countAfterCreate = try viewContext.count(for: RepoMovie.fetchRequest())
        XCTAssert(countAfterCreate == 1, "Count of objects in CoreData should be 1 for read test.")

        movie.title = "Update Success - Edited"

        let exp = expectation(description: "Update a RepoMovie in CoreData")
        let result: AnyPublisher<Movie, CoreDataRepositoryError> = repository
            .update(try XCTUnwrap(movie.url), with: movie)
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Received failure from CRUDRepository.update")
                        exp.fulfill()
                    }
                },
                receiveValue: { resultMovie in
                    XCTAssert(resultMovie == movie, "Success response should match local object.")
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 10)

        let objectId = try XCTUnwrap(
            viewContext.persistentStoreCoordinator?
                .managedObjectID(forURIRepresentation: try XCTUnwrap(movie.url))
        )
        let updatedRepoMovie = try viewContext.existingObject(with: objectId)
        let updatedMovie = try XCTUnwrap(updatedRepoMovie as? RepoMovie).asUnmanaged
        let diff = CustomDump.diff(updatedMovie, movie)
        XCTAssertNil(diff, "CoreData movie should be updated with the new title, but found diff \(diff ?? "").")
    }

    func testUpdateAsyncSuccess() async throws {
        var movie = Movie(id: UUID(), title: "Update Success", releaseDate: Date(), boxOffice: 100)
        let createdMovie: Movie = try await viewContext.perform(schedule: .immediate, {
            let object = RepoMovie(context: self.viewContext)
            object.create(from: movie)
            try self.viewContext.save()
            return object.asUnmanaged
        })
        
        movie.title = "Update Success - Edited"
        
        let result: Result<Movie, CoreDataRepositoryError> = await repository.update(try XCTUnwrap(createdMovie.url), with: movie)

        guard case var .success(resultMovie) = result else {
            XCTFail("Not expecting a failed result")
            return
        }
        
        XCTAssertNotNil(resultMovie.url)
        resultMovie.url = nil
        let diff = CustomDump.diff(resultMovie, movie)
        XCTAssertNil(diff)
    }

    func testUpdateFailure() throws {
        var movie = Movie(id: UUID(), title: "Update Failure", releaseDate: Date(), boxOffice: 100)
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try? viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")
        let repoMovie = movie.asRepoManaged(in: viewContext)
        try? viewContext.save()
        movie.url = repoMovie.objectID.uriRepresentation()
        let countAfterCreate = try? viewContext.count(for: fetchRequest)
        XCTAssert(countAfterCreate == 1, "Count of objects in CoreData should be 1 for read test.")

        viewContext.delete(repoMovie)
        try viewContext.save()

        let countAfterDelete = try? viewContext.count(for: fetchRequest)
        XCTAssert(countAfterDelete == 0, "Count of objects in CoreData should be 0 after delete for read test.")

        let exp = expectation(description: "Fail to update a RepoMovie in CoreData")
        let result: AnyPublisher<Movie, CoreDataRepositoryError> = repository
            .update(try XCTUnwrap(movie.url), with: movie)
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        XCTFail("Received success from CRUDRepository.update when expecting failure.")
                    case .failure:
                        exp.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Not expected to receive a value for CRUDRepository.update")
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 10)
    }

    func testUpdateAsyncFailure() async throws {
        var movie = Movie(id: UUID(), title: "Update Success", releaseDate: Date(), boxOffice: 100)
        let createdMovie: Movie = try await viewContext.perform(schedule: .immediate, {
            let object = RepoMovie(context: self.viewContext)
            object.create(from: movie)
            try self.viewContext.save()
            return object.asUnmanaged
        })

        _ = try await viewContext.perform {
            let objectID = self.viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: try XCTUnwrap(createdMovie.url))
            let object = try self.viewContext.existingObject(with: try XCTUnwrap(objectID))
            self.viewContext.delete(object)
            try self.viewContext.save()
        }
        
        movie.title = "Update Success - Edited"
        
        let result: Result<Movie, CoreDataRepositoryError> = await repository.update(try XCTUnwrap(createdMovie.url), with: movie)

        switch result {
        case .success:
            XCTFail("Not expecting a successful result")
        case .failure:
            XCTAssert(true)
        }
    }

    func testDeleteSuccess() throws {
        var movie = Movie(id: UUID(), title: "Delete Success", releaseDate: Date(), boxOffice: 100)
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try? viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")
        let repoMovie = movie.asRepoManaged(in: viewContext)
        try? viewContext.save()
        movie.url = repoMovie.objectID.uriRepresentation()
        let countAfterCreate = try? viewContext.count(for: RepoMovie.fetchRequest())
        XCTAssert(countAfterCreate == 1, "Count of objects in CoreData should be 1 for read test.")

        let exp = expectation(description: "Delete a RepoMovie in CoreData")
        let result: AnyPublisher<Void, CoreDataRepositoryError> = repository.delete(try XCTUnwrap(movie.url))
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure:
                        XCTFail("Received failure from CRUDRepository.delete")
                        exp.fulfill()
                    }
                },
                receiveValue: { _ in
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)

        let afterDeleteCount = try viewContext.count(for: fetchRequest)
        XCTAssert(afterDeleteCount == 0, "CoreData should have no objects after delete but found \(afterDeleteCount)")
    }

    func testDeleteAsyncSuccess() async throws {
        let movie = Movie(id: UUID(), title: "Delete Success", releaseDate: Date(), boxOffice: 100)
        let createdMovie: Movie = try await viewContext.perform(schedule: .immediate, {
            let object = RepoMovie(context: self.viewContext)
            object.create(from: movie)
            try self.viewContext.save()
            return object.asUnmanaged
        })
        
        let result: Result<Void, CoreDataRepositoryError> = await repository.delete(try XCTUnwrap(createdMovie.url))

        switch result {
        case .success:
            XCTAssert(true)
        case .failure:
            XCTFail("Not expecting a failed result")
        }
    }

    func testDeleteFailure() throws {
        var movie = Movie(id: UUID(), title: "Delete Failure", releaseDate: Date(), boxOffice: 100)
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try? viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")
        let repoMovie = movie.asRepoManaged(in: viewContext)
        try? viewContext.save()
        movie.url = repoMovie.objectID.uriRepresentation()
        let countAfterCreate = try? viewContext.count(for: fetchRequest)
        XCTAssert(countAfterCreate == 1, "Count of objects in CoreData should be 1 for delete test.")

        viewContext.delete(repoMovie)
        try? viewContext.save()

        let exp = expectation(description: "Fail to delete a RepoMovie in CoreData")
        let result: AnyPublisher<Void, CoreDataRepositoryError> = repository.delete(try XCTUnwrap(movie.url))
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        XCTFail("Received success from CRUDRepository.delete when expecting failure.")
                    case .failure:
                        exp.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Not expected to receive a value for CRUDRepository.delete")
                    exp.fulfill()
                }
            )
            .store(in: &cancellables)
        wait(for: [exp], timeout: 5)
    }

    func testDeleteAsyncFailure() async throws {
        let movie = Movie(id: UUID(), title: "Delete Failure", releaseDate: Date(), boxOffice: 100)
        let createdMovie: Movie = try await viewContext.perform(schedule: .immediate, {
            let object = RepoMovie(context: self.viewContext)
            object.create(from: movie)
            try self.viewContext.save()
            return object.asUnmanaged
        })

        _ = try await viewContext.perform {
            let objectID = self.viewContext.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: try XCTUnwrap(createdMovie.url))
            let object = try self.viewContext.existingObject(with: try XCTUnwrap(objectID))
            self.viewContext.delete(object)
            try self.viewContext.save()
        }
        
        let result: Result<Void, CoreDataRepositoryError> = await repository.delete(try XCTUnwrap(createdMovie.url))

        switch result {
        case .success:
            XCTFail("Not expecting a success result")
        case .failure:
            XCTAssert(true)
        }
    }

    func testReadSubscriptionSuccess() throws {
        var movie = Movie(id: UUID(), title: "Read Success", releaseDate: Date(), boxOffice: 100)
        let fetchRequest = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        let count = try? viewContext.count(for: fetchRequest)
        XCTAssert(count == 0, "Count of objects in CoreData should be zero at the start of each test.")
        let repoMovie = movie.asRepoManaged(in: viewContext)
        try? viewContext.save()
        movie.url = repoMovie.objectID.uriRepresentation()
        let countAfterCreate = try? viewContext.count(for: RepoMovie.fetchRequest())
        XCTAssert(countAfterCreate == 1, "Count of objects in CoreData should be 1 for read test.")

        var editedMovie = movie
        editedMovie.title = "New Title"

        let firstExp = expectation(description: "Read a movie from CoreData")
        let secondExp = expectation(description: "Read a movie again after CoreData context is updated")
        var resultCount = 0
        let result: AnyPublisher<Movie, CoreDataRepositoryError> = repository.readSubscription(try XCTUnwrap(movie.url))
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    XCTFail("Not expecting completion since subscription finishes after subscriber cancel")
                case .failure:
                    XCTFail("Not expecting failure")
                }
            }, receiveValue: { receiveMovie in
                resultCount += 1
                switch resultCount {
                case 1:
                    XCTAssert(receiveMovie == movie, "Success response should match local object.")
                    firstExp.fulfill()
                case 2:
                    XCTAssert(receiveMovie == editedMovie, "Second success response should match local object.")
                    secondExp.fulfill()
                default:
                    XCTFail("Not expecting any values past the first two.")
                }

            })
            .store(in: &cancellables)
        wait(for: [firstExp], timeout: 5)
        repository.update(try XCTUnwrap(movie.url), with: editedMovie).sink(
            receiveCompletion: { completion in
                if case .failure = completion {
                    XCTFail("Update should not fail")
                }
            },
            receiveValue: { resultMovie in
                XCTAssert(resultMovie == editedMovie)
            }
        )
        .store(in: &cancellables)
        wait(for: [secondExp], timeout: 5)
        cancellables.forEach { $0.cancel() }
    }
}
