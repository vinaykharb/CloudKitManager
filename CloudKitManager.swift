//
//  CloudKitManager.swift
//
//  Created by Vinay Kharb on 7/1/19.
//

import Foundation
import CloudKit
#if canImport(ReactiveSwift) && canImport(Result)
import ReactiveSwift
import Result
#endif

enum CloudKitError: Error {
	case noAccount
	case restricted
	case couldNotDetermine
}

open class CloudKitManager {
	private var scope: CKDatabase.Scope = .public
	private let container = CKContainer.default()

	private var database: CKDatabase {
		return self.container.database(with: self.scope)
	}

	public init(with scope: CKDatabase.Scope) {
		self.scope = scope
	}

	//check that user has permitted access to iCloud
	#if canImport(ReactiveSwift) && canImport(Result)
	private func requestAccountStatus() -> SignalProducer<CKAccountStatus, AnyError> {
		return SignalProducer { observer, _ in
			self.container.accountStatus { (accountStatus, error) in
				if let responseError = error {
					observer.send(error: AnyError(responseError))
				} else {
					observer.send(value: accountStatus)
					observer.sendCompleted()
				}
			}
		}
	}
	#else
	private func requestAccountStatus(completion: @escaping (CKAccountStatus?, Error?) -> Void) {
		self.container.accountStatus { (accountStatus, error) in
			if let responseError = error {
				completion(nil, responseError)
			} else {
				completion(accountStatus, nil)
			}
		}
	}
	#endif

	public typealias RecordsClosure = ([CKRecord]?, Error?) -> Void
	public typealias RecordClosure = (CKRecord?, Error?) -> Void

	#if canImport(ReactiveSwift) && canImport(Result)
	public func fetchRecords(_ query: CKQuery) -> SignalProducer<[CKRecord]?, AnyError> {
		return self.requestAccountStatus()
			.filter { $0 == .available }
			.then(self.perform(query: query))
	}

	private func perform(query: CKQuery) -> SignalProducer<[CKRecord]?, AnyError> {
		return SignalProducer { observer, _ in
			self.database.perform(query, inZoneWith: nil) { (record, error) in
				if let responseError = error {
					observer.send(error: AnyError(responseError))
				} else {
					observer.send(value: record)
					observer.sendCompleted()
				}
			}
		}
	}

	public func saveRecord(_ record: CKRecord) -> SignalProducer<CKRecord?, AnyError> {
		return self.requestAccountStatus()
			.filter { $0 == .available }
			.then(self.save(record: record))
	}

	private func save(record: CKRecord) -> SignalProducer<CKRecord?, AnyError> {
		return SignalProducer { observer, _ in
			self.database.save(record) { (record, error) in
				DispatchQueue.main.async {
					if let responseError = error {
						observer.send(error: AnyError(responseError))
					} else {
						observer.send(value: record)
						observer.sendCompleted()
					}
				}
			}
		}
	}

	public func saveRecords(_ records: [CKRecord]) -> SignalProducer<[CKRecord], AnyError> {
		return self.requestAccountStatus()
			.filter { $0 == .available }
			.then(self.save(records: records))
	}

	private func save(records: [CKRecord]) -> SignalProducer<[CKRecord], AnyError> {
		return SignalProducer { observer, _ in
			var result = [CKRecord]()
			records.forEach {
				self.database.save($0) { (record, error) in
					DispatchQueue.main.async {
						if let responseError = error {
							observer.send(error: AnyError(responseError))
						} else if let record = record {
							result.append(record)
							if result.count == records.count {
								observer.send(value: result)
								observer.sendCompleted()
							}
						}
					}
				}
			}
		}
	}

	public func updateRecord(_ record: CKRecord) -> SignalProducer<CKRecord?, AnyError> {
		return self.requestAccountStatus()
			.filter { $0 == .available }
			.then(self.update(record: record))
	}

	private func update(record: CKRecord) -> SignalProducer<CKRecord?, AnyError> {
		return SignalProducer { observer, _ in
			let updateOperation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
			updateOperation.savePolicy = .allKeys
			updateOperation.qualityOfService = .userInitiated
			updateOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
				DispatchQueue.main.async {
					if let responseError = error {
						observer.send(error: AnyError(responseError))
					} else {
						observer.send(value: savedRecords?.first)
						observer.sendCompleted()
					}
				}
			}
			self.database.add(updateOperation)
		}
	}

	public func updateRecords(_ records: [CKRecord]? = nil, recordsToDelete: [CKRecord]? = nil) -> SignalProducer<[CKRecord]?, AnyError> {
		return self.requestAccountStatus()
			.filter { $0 == .available }
			.then(self.update(records: records, recordsToDelete: recordsToDelete))
	}

	private func update(records: [CKRecord]? = nil, recordsToDelete: [CKRecord]? = nil) -> SignalProducer<[CKRecord]?, AnyError> {
		return SignalProducer { observer, _ in
			let recordIDsToDelete = recordsToDelete?.compactMap { $0.recordID }
			let updateOperation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: recordIDsToDelete)
			updateOperation.savePolicy = .allKeys
			updateOperation.qualityOfService = .userInitiated
			updateOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
				DispatchQueue.main.async {
					if let responseError = error {
						observer.send(error: AnyError(responseError))
					} else {
						observer.send(value: savedRecords)
						observer.sendCompleted()
					}
				}
			}
			self.database.add(updateOperation)
		}
	}
	#else
	public func fetchRecords(_ query: CKQuery, completion: @escaping RecordsClosure) {
		self.requestAccountStatus { (accountStatus, error) in
			if let accountStatus = accountStatus, accountStatus == .available {
				self.fetch(query: query, completion: completion)
			}
		}
	}

	private func fetch(query: CKQuery, completion: @escaping RecordsClosure) {
		self.database.perform(query, inZoneWith: nil) { (records, error) in
			if let responseError = error {
				completion(nil, responseError)
			} else {
				completion(records, nil)
			}
		}
	}

	public func saveRecord(_ record: CKRecord, completion: @escaping RecordClosure) {
		self.requestAccountStatus { (accountStatus, error) in
			if let accountStatus = accountStatus, accountStatus == .available {
				self.save(record: record, completion: completion)
			}
		}
	}

	private func save(record: CKRecord, completion: @escaping RecordClosure) {
		self.database.save(record) { (record, error) in
			DispatchQueue.main.async {
				if let responseError = error {
					completion(nil, responseError)
				} else {
					completion(record, nil)
				}
			}
		}
	}

	public func saveRecords(_ records: [CKRecord], completion: @escaping RecordsClosure) {
		self.requestAccountStatus { (accountStatus, error) in
			if let accountStatus = accountStatus, accountStatus == .available {
				self.save(records: records, completion: completion)
			}
		}
	}

	private func save(records: [CKRecord], completion: @escaping RecordsClosure) {
		var result = [CKRecord]()
		records.forEach {
			self.database.save($0) { (record, error) in
				DispatchQueue.main.async {
					if let responseError = error {
						completion(nil, responseError)
					} else if let record = record {
						result.append(record)
						if result.count == records.count {
							completion(result, nil)
						}
					}
				}
			}
		}
	}

	public func updateRecord(_ record: CKRecord, completion: @escaping RecordClosure) {
		self.requestAccountStatus { (accountStatus, error) in
			if let accountStatus = accountStatus, accountStatus == .available {
				self.update(record: record, completion: completion)
			}
		}
	}

	private func update(record: CKRecord, completion: @escaping RecordClosure) {
		let updateOperation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
		updateOperation.savePolicy = .allKeys
		updateOperation.qualityOfService = .userInitiated
		updateOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
			DispatchQueue.main.async {
				if let responseError = error {
					completion(nil, responseError)
				} else {
					completion(savedRecords?.first, nil)
				}
			}
		}
		self.database.add(updateOperation)
	}

	public func updateRecords(_ records: [CKRecord]? = nil, recordsToDelete: [CKRecord]? = nil, completion: @escaping RecordsClosure) {
		self.requestAccountStatus { (accountStatus, error) in
			if let accountStatus = accountStatus, accountStatus == .available {
				self.update(records: records, recordsToDelete: recordsToDelete, completion: completion)
			}
		}
	}

	private func update(records: [CKRecord]? = nil, recordsToDelete: [CKRecord]? = nil, completion: @escaping RecordsClosure) {
		let recordIDsToDelete = recordsToDelete?.compactMap { $0.recordID }
		let updateOperation = CKModifyRecordsOperation(recordsToSave: records, recordIDsToDelete: recordIDsToDelete)
		updateOperation.savePolicy = .allKeys
		updateOperation.qualityOfService = .userInitiated
		updateOperation.modifyRecordsCompletionBlock = { savedRecords, deletedRecordIDs, error in
			DispatchQueue.main.async {
				if let responseError = error {
					completion(nil, responseError)
				} else {
					completion(savedRecords, nil)
				}
			}
		}
		self.database.add(updateOperation)
	}
	#endif
}
