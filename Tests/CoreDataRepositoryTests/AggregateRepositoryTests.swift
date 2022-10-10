// AggregateRepositoryTests.swift
// CoreDataRepository
//
//
// MIT License
//
// Copyright © 2022 Andrew Roan

import Combine
import CoreData
import CoreDataRepository
import XCTest

final class AggregateRepositoryTests: CoreDataXCTestCase {
    static var allTests = [
        ("testCountSuccess", testCountSuccess),
        ("testSumSuccess", testSumSuccess),
        ("testAverageSuccess", testAverageSuccess),
        ("testMinSuccess", testMinSuccess),
        ("testMaxSuccess", testMaxSuccess),
    ]

    let fetchRequest: NSFetchRequest<RepoMovie> = {
        let request = NSFetchRequest<RepoMovie>(entityName: "RepoMovie")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \RepoMovie.title, ascending: true)]
        return request
    }()

    let movies = [
        Movie(id: UUID(), title: "A", releaseDate: Date(), boxOffice: 10),
        Movie(id: UUID(), title: "B", releaseDate: Date(), boxOffice: 20),
        Movie(id: UUID(), title: "C", releaseDate: Date(), boxOffice: 30),
        Movie(id: UUID(), title: "D", releaseDate: Date(), boxOffice: 40),
        Movie(id: UUID(), title: "E", releaseDate: Date(), boxOffice: 50),
    ]
    var objectIDs = [NSManagedObjectID]()

    override func setUpWithError() throws {
        try super.setUpWithError()
        objectIDs = try movies.map { $0.asRepoManaged(in: try self.viewContext()).objectID }
        try viewContext().save()
    }

    override func tearDownWithError() throws {
        try super.tearDownWithError()
        objectIDs = []
    }

    func testCountSuccess() throws {
        let exp = expectation(description: "Get count of movies from CoreData")
        let result: AnyPublisher<[[String: Int]], CoreDataRepositoryError> = try repository()
            .count(predicate: NSPredicate(value: true), entityDesc: RepoMovie.entity())
        var values: [[String: Int]] = []
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure:
                    XCTFail("Not expecting failure")
                }
            }, receiveValue: { _values in
                values = _values
                exp.fulfill()
            })
            .store(in: &cancellables)
        wait(for: [exp], timeout: 30)
        let firstValue = try XCTUnwrap(values.first?.values.first)
        XCTAssert(firstValue == 5, "Result value (count) should equal number of movies.")
    }

    func testSumSuccess() throws {
        let exp = expectation(description: "Get sum of CoreData Movies boxOffice")
        var values: [[String: Decimal]] = []
        let result: AnyPublisher<[[String: Decimal]], CoreDataRepositoryError> = try repository().sum(
            predicate: NSPredicate(value: true),
            entityDesc: RepoMovie.entity(),
            attributeDesc: RepoMovie.entity().attributesByName.values.first(where: { $0.name == "boxOffice" })!
        )
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure:
                    XCTFail("Not expecting failure")
                }
            }, receiveValue: { _values in
                values = _values
                exp.fulfill()
            })
            .store(in: &cancellables)
        wait(for: [exp], timeout: 30)
        let firstValue = try XCTUnwrap(values.first?.values.first)
        XCTAssert(
            firstValue == 150,
            "Result value (sum) should equal sum of movies box office."
        )
    }

    func testAverageSuccess() throws {
        let exp = expectation(description: "Get average of CoreData Movies boxOffice")
        var values: [[String: Decimal]] = []
        let result: AnyPublisher<[[String: Decimal]], CoreDataRepositoryError> = try repository().average(
            predicate: NSPredicate(value: true),
            entityDesc: RepoMovie.entity(),
            attributeDesc: RepoMovie.entity().attributesByName.values.first(where: { $0.name == "boxOffice" })!
        )
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure:
                    XCTFail("Not expecting failure")
                }
            }, receiveValue: { _values in
                values = _values
                exp.fulfill()
            })
            .store(in: &cancellables)
        wait(for: [exp], timeout: 30)
        let firstValue = try XCTUnwrap(values.first?.values.first)
        XCTAssert(
            firstValue == 30,
            "Result value should equal average of movies box office."
        )
    }

    func testMinSuccess() throws {
        let exp = expectation(description: "Get average of CoreData Movies boxOffice")
        var values: [[String: Decimal]] = []
        let result: AnyPublisher<[[String: Decimal]], CoreDataRepositoryError> = try repository().min(
            predicate: NSPredicate(value: true),
            entityDesc: RepoMovie.entity(),
            attributeDesc: RepoMovie.entity().attributesByName.values.first(where: { $0.name == "boxOffice" })!
        )
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure:
                    XCTFail("Not expecting failure")
                }
            }, receiveValue: { _values in
                values = _values
                exp.fulfill()
            })
            .store(in: &cancellables)
        wait(for: [exp], timeout: 30)
        let firstValue = try XCTUnwrap(values.first?.values.first)
        XCTAssert(
            firstValue == 10,
            "Result value should equal average of movies box office."
        )
    }

    func testMaxSuccess() throws {
        let exp = expectation(description: "Get average of CoreData Movies boxOffice")
        var values: [[String: Decimal]] = []
        let result: AnyPublisher<[[String: Decimal]], CoreDataRepositoryError> = try repository().max(
            predicate: NSPredicate(value: true),
            entityDesc: RepoMovie.entity(),
            attributeDesc: RepoMovie.entity().attributesByName.values.first(where: { $0.name == "boxOffice" })!
        )
        result.subscribe(on: backgroundQueue)
            .receive(on: mainQueue)
            .sink(receiveCompletion: { completion in
                switch completion {
                case .finished:
                    break
                case .failure:
                    XCTFail("Not expecting failure")
                }
            }, receiveValue: { _values in
                values = _values
                exp.fulfill()
            })
            .store(in: &cancellables)
        wait(for: [exp], timeout: 30)
        let firstValue = try XCTUnwrap(values.first?.values.first)
        XCTAssert(
            firstValue == 50,
            "Result value should equal average of movies box office."
        )
    }
}
