@testable import MongoSwift
import Nimble
import XCTest

final class CodecTests: XCTestCase {
    static var allTests: [(String, (CodecTests) -> () throws -> Void)] {
        return [
            ("testEncodeListDatabasesOptions", testEncodeListDatabasesOptions),
            ("testStructs", testStructs),
            ("testOptionals", testOptionals),
            ("testEncodingNonBsonNumbers", testEncodingNonBsonNumbers),
            ("testDecodingNonBsonNumbers", testEncodingNonBsonNumbers),
            ("testBsonNumbers", testEncodingNonBsonNumbers),
            ("testBsonValues", testBsonValues),
            ("testDecodeScalars", testDecodeScalars),
            ("testDocumentIsCodable", testDocumentIsCodable),
            ("testEncodeArray", testEncodeArray),
            ("testAnyBsonValueIsBsonCodable", testAnyBsonValueIsBsonCodable)
        ]
    }

    func testEncodeListDatabasesOptions() throws {
        let options = ListDatabasesOptions(filter: Document(["a": 10]), nameOnly: true, session: ClientSession())
        let expected: Document = ["filter": ["a": 10] as Document, "nameOnly": true, "session": Document()]
        expect(try BsonEncoder().encode(options)).to(equal(expected))
    }

    struct TestClass: Encodable {
        let val1 = "a"
        let val2 = 0
        let val3 = [[1, 2], [3, 4]]
        let val4 = TestClass2()
        let val5 = [TestClass2()]
    }

    struct TestClass2: Encodable {
        let x = 1
        let y = 2
    }

    struct BasicStruct: Codable, Equatable {
        let int: Int
        let string: String

        public static func == (lhs: BasicStruct, rhs: BasicStruct) -> Bool {
            return lhs.int == rhs.int && lhs.string == rhs.string
        }
    }

    struct NestedStruct: Codable, Equatable {
        let s1: BasicStruct
        let s2: BasicStruct

        public static func == (lhs: NestedStruct, rhs: NestedStruct) -> Bool {
            return lhs.s1 == rhs.s1 && lhs.s2 == rhs.s2
        }
    }

    struct NestedArray: Codable, Equatable {
        let array: [BasicStruct]

        public static func == (lhs: NestedArray, rhs: NestedArray) -> Bool {
            return lhs.array == rhs.array
        }
    }

    struct NestedNestedStruct: Codable, Equatable {
        let s: NestedStruct

        public static func == (lhs: NestedNestedStruct, rhs: NestedNestedStruct) -> Bool {
            return lhs.s == rhs.s
        }
    }

    /// Test encoding/decoding a variety of structs containing simple types that have 
    /// built in Codable support (strings, arrays, ints, and structs composed of them.)
    func testStructs() throws {
        let encoder = BsonEncoder()
        let decoder = BsonDecoder()

        let expected: Document = [
            "val1": "a",
            "val2": 0,
            "val3": [[1, 2], [3, 4]],
            "val4": ["x": 1, "y": 2] as Document,
            "val5": [["x": 1, "y": 2] as Document]
        ]

        expect(try encoder.encode(TestClass())).to(equal(expected))

        // a basic struct 
        let basic1 = BasicStruct(int: 1, string: "hello")
        let basic1Doc: Document = ["int": 1, "string": "hello"]
        expect(try encoder.encode(basic1)).to(equal(basic1Doc))
        expect(try decoder.decode(BasicStruct.self, from: basic1Doc)).to(equal(basic1))

        // a struct storing two nested structs as properties
        let basic2 = BasicStruct(int: 2, string: "hi")
        let basic2Doc: Document = ["int": 2, "string": "hi"]

        let nestedStruct = NestedStruct(s1: basic1, s2: basic2)
        let nestedStructDoc: Document = ["s1": basic1Doc, "s2": basic2Doc]
        expect(try encoder.encode(nestedStruct)).to(equal(nestedStructDoc))
        expect(try decoder.decode(NestedStruct.self, from: nestedStructDoc)).to(equal(nestedStruct))

        // a struct storing two nested structs in an array
        let nestedArray = NestedArray(array: [basic1, basic2])
        let nestedArrayDoc: Document = ["array": [basic1Doc, basic2Doc]]
        expect(try encoder.encode(nestedArray)).to(equal(nestedArrayDoc))
        expect(try decoder.decode(NestedArray.self, from: nestedArrayDoc)).to(equal(nestedArray))

        // one more level of nesting
        let nestedNested = NestedNestedStruct(s: nestedStruct)
        let nestedNestedDoc: Document = ["s": nestedStructDoc]
        expect(try encoder.encode(nestedNested)).to(equal(nestedNestedDoc))
        expect(try decoder.decode(NestedNestedStruct.self, from: nestedNestedDoc)).to(equal(nestedNested))
    }

    struct OptionalsStruct: Codable, Equatable {
        let int: Int?
        let bool: Bool?
        let string: String

        public static func == (lhs: OptionalsStruct, rhs: OptionalsStruct) -> Bool {
            return lhs.int == rhs.int && lhs.bool == rhs.bool && lhs.string == rhs.string
        }
    }

    /// Test encoding/decoding a struct containing optional values.
    func testOptionals() throws {
        let encoder = BsonEncoder()
        let decoder = BsonDecoder()

        let s1 = OptionalsStruct(int: 1, bool: true, string: "hi")
        let s1Doc: Document = ["int": 1, "bool": true, "string": "hi"]
        expect(try encoder.encode(s1)).to(equal(s1Doc))
        expect(try decoder.decode(OptionalsStruct.self, from: s1Doc)).to(equal(s1))

        let s2 = OptionalsStruct(int: nil, bool: true, string: "hi")
        let s2Doc1: Document = ["bool": true, "string": "hi"]
        expect(try encoder.encode(s2)).to(equal(s2Doc1))
        expect(try decoder.decode(OptionalsStruct.self, from: s2Doc1)).to(equal(s2))

        // test with key in doc explicitly set to nil
        let s2Doc2: Document = ["int": nil, "bool": true, "string": "hi"]
        expect(try decoder.decode(OptionalsStruct.self, from: s2Doc2)).to(equal(s2))
    }

    struct Numbers: Codable, Equatable {
        let int8: Int8?
        let int16: Int16?
        let uint8: UInt8?
        let uint16: UInt16?
        let uint32: UInt32?
        let uint64: UInt64?
        let uint: UInt?
        let float: Float?

        static let keys = ["int8", "int16", "uint8", "uint16", "uint32", "uint64", "uint", "float"]

        public static func == (lhs: Numbers, rhs: Numbers) -> Bool {
            return lhs.int8 == rhs.int8 && lhs.int16 == rhs.int16 &&
                    lhs.uint8 == rhs.uint8 && lhs.uint16 == rhs.uint16 &&
                    lhs.uint32 == rhs.uint32 && lhs.uint64 == rhs.uint64 &&
                    lhs.uint == rhs.uint && lhs.float == rhs.float
        }

        init(int8: Int8? = nil, int16: Int16? = nil, uint8: UInt8? = nil, uint16: UInt16? = nil,
             uint32: UInt32? = nil, uint64: UInt64? = nil, uint: UInt? = nil, float: Float? = nil) {
            self.int8 = int8
            self.int16 = int16
            self.uint8 = uint8
            self.uint16 = uint16
            self.uint32 = uint32
            self.uint64 = uint64
            self.uint = uint
            self.float = float
        }
    }

    /// Test encoding where the struct's numeric types are non-BSON
    /// and require conversions.
    func testEncodingNonBsonNumbers() throws {
        let encoder = BsonEncoder()

        let s1 = Numbers(int8: 42, int16: 42, uint8: 42, uint16: 42, uint32: 42, uint64: 42, uint: 42, float: 42)
        // all should be stored as Int32s, except the float should be stored as a double
        let doc1: Document = ["int8": 42, "int16": 42, "uint8": 42, "uint16": 42,
                    "uint32": 42, "uint64": 42, "uint": 42, "float": 42.0]

        expect(try encoder.encode(s1)).to(equal(doc1))

        // check that a UInt32 too large for an Int32 gets converted to Int64
        expect(try encoder.encode(Numbers(uint32: 4294967295))).to(equal(["uint32": Int64(4294967295)]))

        // check that UInt, UInt64 too large for an Int32 gets converted to Int64
        expect(try encoder.encode(Numbers(uint64: 4294967295))).to(equal(["uint64": Int64(4294967295)]))
        expect(try encoder.encode(Numbers(uint: 4294967295))).to(equal(["uint": Int64(4294967295)]))

        // check that UInt, UInt64 too large for an Int64 gets converted to Double
        expect(try encoder.encode(Numbers(uint64: UInt64(Int64.max) + 1))).to(equal(["uint64": 9223372036854775808.0]))
        expect(try encoder.encode(Numbers(uint: UInt(Int64.max) + 1))).to(equal(["uint": 9223372036854775808.0]))

        // check that we fail gracefully with a UInt, UInt64 that can't fit in any type.
        // Swift 4.0 is unable to properly handle these edge cases and returns incorrect
        // values from `Double(exactly:)`.
        // 4.1 fixes this -- see https://bugs.swift.org/browse/SR-7056.
        #if swift(>=4.1)
        expect(try encoder.encode(Numbers(uint64: UInt64.max))).to(throwError())
        expect(try encoder.encode(Numbers(uint: UInt.max))).to(throwError())
        #endif
    }

    /// Test decoding where the requested numeric types are non-BSON
    /// and require conversions.
    func testDecodingNonBsonNumbers() throws {
        let decoder = BsonDecoder()

        // the struct we expect to get back
        let s = Numbers(int8: 42, int16: 42, uint8: 42, uint16: 42, uint32: 42, uint64: 42, uint: 42, float: 42)

        // store all values as Int32s and decode them to their requested types
        var doc1 = Document()
        for k in Numbers.keys {
            doc1[k] = 42
        }
        let res1 = try decoder.decode(Numbers.self, from: doc1)
        expect(res1).to(equal(s))

        // store all values as Int64s and decode them to their requested types.
        var doc2 = Document()
        for k in Numbers.keys {
            doc2[k] = Int64(42)
        }

        let res2 = try decoder.decode(Numbers.self, from: doc2)
        expect(res2).to(equal(s))

        // store all values as Doubles and decode them to their requested types
        var doc3 = Document()
        for k in Numbers.keys {
            doc3[k] = Double(42)
        }

        let res3 = try decoder.decode(Numbers.self, from: doc3)
        expect(res3).to(equal(s))

        // test for each type that we fail gracefully when values cannot be represented because they are out of bounds
        expect(try decoder.decode(Numbers.self, from: ["int8": Int(Int8.max) + 1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["int16": Int(Int16.max) + 1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["uint8": -1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: [ "uint16": -1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["uint32": -1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["uint64": -1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["uint": -1])).to(throwError())
        expect(try decoder.decode(Numbers.self, from: ["float": Double.greatestFiniteMagnitude])).to(throwError())
    }

     struct BsonNumbers: Codable, Equatable {
        let int: Int
        let int32: Int32
        let int64: Int64
        let double: Double

        public static func == (lhs: BsonNumbers, rhs: BsonNumbers) -> Bool {
            return lhs.int == rhs.int && lhs.int32 == rhs.int32 &&
                    lhs.int64 == rhs.int64 && lhs.double == rhs.double
        }
    }

    /// Test that BSON number types are encoded properly, and can be decoded from any type they are stored as
    func testBsonNumbers() throws {
        let encoder = BsonEncoder()
        let decoder = BsonDecoder()
        // the struct we expect to get back
        let s = BsonNumbers(int: 42, int32: 42, int64: 42, double: 42)
        expect(try encoder.encode(s)).to(equal(["int": Int(42), "int32": Int32(42), "int64": Int64(42), "double": Double(42)]))

        // store all values as Int32s and decode them to their requested types
        let doc1: Document = ["int": Int32(42), "int32": Int32(42), "int64": Int32(42), "double": Int32(42)]
        expect(try decoder.decode(BsonNumbers.self, from: doc1)).to(equal(s))

        // store all values as Int64s and decode them to their requested types
        let doc2: Document = ["int": Int64(42), "int32": Int64(42), "int64": Int64(42), "double": Int64(42)]
        expect(try decoder.decode(BsonNumbers.self, from: doc2)).to(equal(s))

        // store all values as Doubles and decode them to their requested types
        let doc3: Document = ["int": Double(42), "int32": Double(42), "int64": Double(42), "double": Double(42)]
        expect(try decoder.decode(BsonNumbers.self, from: doc3)).to(equal(s))
    }

    struct AllBsonTypes: Codable, Equatable {
        let double: Double
        let string: String
        let doc: Document
        let arr: [Int]
        let binary: Binary
        let oid: ObjectId
        let bool: Bool
        let date: Date
        let code: CodeWithScope
        let int: Int
        let ts: Timestamp
        let int32: Int32
        let int64: Int64
        let dec: Decimal128
        let minkey: MinKey
        let maxkey: MaxKey
        let regex: RegularExpression

        public static func == (lhs: AllBsonTypes, rhs: AllBsonTypes) -> Bool {
            return lhs.double == rhs.double && lhs.string == rhs.string &&
                    lhs.doc == rhs.doc && lhs.arr == rhs.arr && lhs.binary == rhs.binary &&
                    lhs.oid == rhs.oid && lhs.bool == rhs.bool && lhs.code == rhs.code &&
                    lhs.int == rhs.int && lhs.ts == rhs.ts && lhs.int32 == rhs.int32 &&
                    lhs.int64 == rhs.int64 && lhs.dec == rhs.dec && lhs.minkey == rhs.minkey &&
                    lhs.maxkey == rhs.maxkey && lhs.regex == rhs.regex && lhs.date == rhs.date
        }
    }

    /// Test decoding/encoding to all possible BSON types
    func testBsonValues() throws {

        let expected = AllBsonTypes(
                            double: Double(2),
                            string: "hi",
                            doc: ["x": 1],
                            arr: [1, 2],
                            binary: Binary(base64: "//8=", subtype: .binary),
                            oid: ObjectId(fromString: "507f1f77bcf86cd799439011"),
                            bool: true,
                            date: Date(timeIntervalSinceReferenceDate: 5000),
                            code: CodeWithScope(code: "hi", scope: ["x": 1]),
                            int: 1,
                            ts: Timestamp(timestamp: 1, inc: 2),
                            int32: 5,
                            int64: 6,
                            dec: Decimal128("1.2E+10"),
                            minkey: MinKey(),
                            maxkey: MaxKey(),
                            regex: RegularExpression(pattern: "^abc", options: "imx")
                        )

        let decoder = BsonDecoder()

        let doc: Document = [
            "double": Double(2),
            "string": "hi",
            "doc": ["x": 1] as Document,
            "arr": [1, 2],
            "binary": Binary(base64: "//8=", subtype: .binary),
            "oid": ObjectId(fromString: "507f1f77bcf86cd799439011"),
            "bool": true,
            "date": Date(timeIntervalSinceReferenceDate: 5000),
            "code": CodeWithScope(code: "hi", scope: ["x": 1]),
            "int": 1,
            "ts": Timestamp(timestamp: 1, inc: 2),
            "int32": 5,
            "int64": Int64(6),
            "dec": Decimal128("1.2E+10"),
            "minkey": MinKey(),
            "maxkey": MaxKey(),
            "regex": RegularExpression(pattern: "^abc", options: "imx")
        ]

        let res = try decoder.decode(AllBsonTypes.self, from: doc)
        expect(res).to(equal(expected))

        expect(try BsonEncoder().encode(expected)).to(equal(doc))

        let base64 = "//8="
        let extjson = """
        {
            "double" : 2.0,
            "string" : "hi",
            "doc" : { "x" : 1 },
            "arr" : [ 1, 2 ],
            "binary" : { "$binary" : { "base64": "\(base64)", "subType" : "00" } },
            "oid" : { "$oid" : "507f1f77bcf86cd799439011" },
            "bool" : true,
            "date" : { "$date" : "2001-01-01T01:23:20Z" },
            "code" : { "$code" : "hi", "$scope" : { "x" : 1 } },
            "int" : 1,
            "ts" : { "$timestamp" : { "t" : 1, "i" : 2 } },
            "int32" : 5, "int64" : 6,
            "dec" : { "$numberDecimal" : "1.2E+10" },
            "minkey" : { "$minKey" : 1 },
            "maxkey" : { "$maxKey" : 1 },
            "regex" : { "$regularExpression" : { "pattern" : "^abc", "options" : "imx" } }
        }
        """

        let res2 = try decoder.decode(AllBsonTypes.self, from: extjson)
        expect(res2).to(equal(expected))
    }

    /// Test decoding extJSON and JSON for standalone values
    func testDecodeScalars() throws {
        let decoder = BsonDecoder()

        expect(try decoder.decode(Int32.self, from: "42")).to(equal(Int32(42)))
        expect(try decoder.decode(Int32.self, from: "{\"$numberInt\": \"42\"}")).to(equal(Int32(42)))

        let oid = ObjectId(fromString: "507f1f77bcf86cd799439011")
        expect(try decoder.decode(ObjectId.self, from: "{\"$oid\": \"507f1f77bcf86cd799439011\"}")).to(equal(oid))

        expect(try decoder.decode(String.self, from: "\"somestring\"")).to(equal("somestring"))

        expect(try decoder.decode(Int64.self, from: "42")).to(equal(Int64(42)))
        expect(try decoder.decode(Int64.self, from: "{\"$numberLong\": \"42\"}")).to(equal(Int64(42)))

        expect(try decoder.decode(Double.self, from: "42.42")).to(equal(42.42))
        expect(try decoder.decode(Double.self, from: "{\"$numberDouble\": \"42.42\"}")).to(equal(42.42))

        expect(try decoder.decode(Decimal128.self,
            from: "{\"$numberDecimal\": \"1.2E+10\"}")).to(equal(Decimal128("1.2E+10")))

        let binary = Binary(base64: "//8=", subtype: .binary)
        expect(try decoder.decode(Binary.self,
            from: "{\"$binary\" : {\"base64\": \"//8=\", \"subType\" : \"00\"}}")).to(equal(binary))

        expect(try decoder.decode(CodeWithScope.self, from: "{\"code\": \"hi\" }")).to(equal(CodeWithScope(code: "hi")))
        let cws = CodeWithScope(code: "hi", scope: ["x": 1])
        expect(try decoder.decode(CodeWithScope.self,
            from: "{\"code\": \"hi\", \"scope\": {\"x\" : 1} }")).to(equal(cws))
        expect(try decoder.decode(Document.self, from: "{\"x\": 1}")).to(equal(["x": 1]))

        let ts = Timestamp(timestamp: 1, inc: 2)
        expect(try decoder.decode(Timestamp.self, from: "{ \"$timestamp\" : { \"t\" : 1, \"i\" : 2 } }")).to(equal(ts))

        let regex = RegularExpression(pattern: "^abc", options: "imx")
        expect(try decoder.decode(RegularExpression.self,
            from: "{ \"$regularExpression\" : { \"pattern\" :\"^abc\", \"options\" : \"imx\" } }")).to(equal(regex))

        expect(try decoder.decode(MinKey.self, from: "{\"$minKey\": 1}")).to(equal(MinKey()))
        expect(try decoder.decode(MaxKey.self, from: "{\"$maxKey\": 1}")).to(equal(MaxKey()))

        expect(try decoder.decode(Bool.self, from: "false")).to(beFalse())
        expect(try decoder.decode(Bool.self, from: "true")).to(beTrue())

        expect(try decoder.decode([Int].self, from: "[1, 2, 3]")).to(equal([1, 2, 3]))
    }

    // test that Document.init(from decoder: Decoder) works with a non BSON decoder and that
    // Document.encode(to encoder: Encoder) works with a non BSON encoder
    func testDocumentIsCodable() throws {
#if os(macOS) // presently skipped on linux due to nondeterministic key ordering
        // note: instead of doing this, one can and should just initialize a Document with the `init(fromJSON:)`
        // constructor, and conver to JSON using the .extendedJSON property. this test is just to demonstrate 
        // that a Document can theoretically work with any encoder/decoder.
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let json = """
        {
            "name": "Durian",
            "points": 600,
            "description": "A fruit with a distinctive scent.",
            "array": ["a", "b", "c"],
            "doc": { "x" : 2.0 }
        }
        """

        let expected: Document = [
            "name": "Durian",
            "points": 600,
            "description": "A fruit with a distinctive scent.",
            "array": ["a", "b", "c"],
            "doc": ["x": 2] as Document
        ]

        let decoded = try decoder.decode(Document.self, from: json.data(using: .utf8)!)
        expect(decoded).to(sortedEqual(expected))

        let encoded = try String(data: encoder.encode(expected), encoding: .utf8)
        expect(encoded).to(cleanEqual(json))
#endif
    }

    func testEncodeArray() throws {
        let encoder = BsonEncoder()

        let values1 = [BasicStruct(int: 1, string: "hello"), BasicStruct(int: 2, string: "hi")]
        expect(try encoder.encode(values1)).to(equal([["int": 1, "string": "hello"], ["int": 2, "string": "hi"]]))

        let values2 = [BasicStruct(int: 1, string: "hello"), nil]
        expect(try encoder.encode(values2)).to(equal([["int": 1, "string": "hello"], nil]))
    }

    struct AnyBsonStruct: Codable {
        let x: AnyBsonValue

        init(_ x: BsonValue) {
            self.x = AnyBsonValue(x)
        }
    }

    // test encoding/decoding AnyBsonValues with BsonEncoder and Decoder
    func testAnyBsonValueIsBsonCodable() throws {
        let encoder = BsonEncoder()
        let decoder = BsonDecoder()

        // standalone document
        let doc: Document = ["y": 1]
        expect(try encoder.encode(AnyBsonValue(doc))).to(equal(doc))
        expect(try decoder.decode(AnyBsonValue.self, from: doc).value as? Document).to(equal(doc))
        expect(try decoder.decode(AnyBsonValue.self, from: doc.canonicalExtendedJSON).value as? Document).to(equal(doc))
        // doc wrapped in a struct

        let wrappedDoc: Document = ["x": doc]
        expect(try encoder.encode(AnyBsonStruct(doc))).to(equal(wrappedDoc))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedDoc).x.value as? Document).to(equal(doc))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedDoc.canonicalExtendedJSON).x.value as? Document).to(equal(doc))

        // values wrapped in an `AnyBsonStruct`
        let double = 42.0
        expect(try decoder.decode(AnyBsonValue.self,
            from: "{\"$numberDouble\": \"42\"}").value as? Double).to(equal(double))

        let wrappedDouble: Document = ["x": double]
        expect(try encoder.encode(AnyBsonStruct(double))).to(equal(wrappedDouble))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedDouble).x.value as? Double).to(equal(double))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedDouble.canonicalExtendedJSON).x.value as? Double).to(equal(double))

        // string
        let string = "hi"
        expect(try decoder.decode(AnyBsonValue.self, from: "\"hi\"").value as? String).to(equal(string))

        let wrappedString: Document = ["x": string]
        expect(try encoder.encode(AnyBsonStruct(string))).to(equal(wrappedString))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedString).x.value as? String).to(equal(string))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedString.canonicalExtendedJSON).x.value as? String).to(equal(string))

        // array
        let array: [BsonValue] = [1, 2, "hello"]

        let decodedArray = try decoder.decode(AnyBsonValue.self, from: "[1, 2, \"hello\"]").value as? [BsonValue]
        expect(decodedArray?[0] as? Int).to(equal(1))
        expect(decodedArray?[1] as? Int).to(equal(2))
        expect(decodedArray?[2] as? String).to(equal("hello"))

        let wrappedArray: Document = ["x": array]
        expect(try encoder.encode(AnyBsonStruct(array))).to(equal(wrappedArray))
        let decodedWrapped = try decoder.decode(AnyBsonStruct.self, from: wrappedArray).x.value as? [BsonValue]
        expect(decodedWrapped?[0] as? Int).to(equal(1))
        expect(decodedWrapped?[1] as? Int).to(equal(2))
        expect(decodedWrapped?[2] as? String).to(equal("hello"))

        // binary
        let binary = Binary(base64: "//8=", subtype: .binary)

        expect(try decoder.decode(AnyBsonValue.self,
            from: "{\"$binary\" : {\"base64\": \"//8=\", \"subType\" : \"00\"}}").value as? Binary).to(equal(binary))

        let wrappedBinary: Document = ["x": binary]
        expect(try encoder.encode(AnyBsonStruct(binary))).to(equal(wrappedBinary))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedBinary).x.value as? Binary).to(equal(binary))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedBinary.canonicalExtendedJSON).x.value as? Binary).to(equal(binary))

        // objectid
        let oid = ObjectId()

        expect(try decoder.decode(AnyBsonValue.self,
            from: "{\"$oid\": \"\(oid.oid)\"}").value as? ObjectId).to(equal(oid))

        let wrappedOid: Document = ["x": oid]
        expect(try encoder.encode(AnyBsonStruct(oid))).to(equal(wrappedOid))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedOid).x.value as? ObjectId).to(equal(oid))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedOid.canonicalExtendedJSON).x.value as? ObjectId).to(equal(oid))

        // bool
        let bool = true

        expect(try decoder.decode(AnyBsonValue.self, from: "true").value as? Bool).to(equal(bool))

        let wrappedBool: Document = ["x": bool]
        expect(try encoder.encode(AnyBsonStruct(bool))).to(equal(wrappedBool))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedBool).x.value as? Bool).to(equal(bool))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedBool.canonicalExtendedJSON).x.value as? Bool).to(equal(bool))

        // date
        let date = Date(timeIntervalSince1970: 5000)

        expect(try decoder.decode(AnyBsonValue.self, from: "{ \"$date\" : { \"$numberLong\" : \"5000000\" } }").value as? Date).to(equal(date))

        let wrappedDate: Document = ["x": date]
        expect(try encoder.encode(AnyBsonStruct(date))).to(equal(wrappedDate))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedDate).x.value as? Date).to(equal(date))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedDate.canonicalExtendedJSON).x.value as? Date).to(equal(date))

        // regex
        let regex = RegularExpression(pattern: "abc", options: "imx")

        expect(try decoder.decode(AnyBsonValue.self,
            from: "{ \"$regularExpression\" : { \"pattern\" : \"abc\", \"options\" : \"imx\" } }")
            .value as? RegularExpression).to(equal(regex))

        let wrappedRegex: Document = ["x": regex]
        expect(try encoder.encode(AnyBsonStruct(regex))).to(equal(wrappedRegex))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedRegex).x.value as? RegularExpression).to(equal(regex))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedRegex.canonicalExtendedJSON).x.value as? RegularExpression).to(equal(regex))

        // codewithscope
        let code = CodeWithScope(code: "console.log(x);", scope: ["x": 1])

        expect(try decoder.decode(AnyBsonValue.self,
            from: "{ \"$code\" : \"console.log(x);\", \"$scope\" : { \"x\" : { \"$numberInt\" : \"1\" } } }")
            .value as? CodeWithScope).to(equal(code))

        let wrappedCode: Document = ["x": code]
        expect(try encoder.encode(AnyBsonStruct(code))).to(equal(wrappedCode))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedCode).x.value as? CodeWithScope).to(equal(code))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedCode.canonicalExtendedJSON).x.value as? CodeWithScope).to(equal(code))

        // int32
        let int32 = Int32(5)

        expect(try decoder.decode(AnyBsonValue.self, from: "{ \"$numberInt\" : \"5\" }").value as? Int).to(equal(5))

        let wrappedInt32: Document = ["x": int32]
        expect(try encoder.encode(AnyBsonStruct(int32))).to(equal(wrappedInt32))
        // as int because we convert Int32 -> Int when decoding
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedInt32).x.value as? Int).to(equal(5))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedInt32.canonicalExtendedJSON).x.value as? Int).to(equal(5))

        // int
        let int = 5

        expect(try decoder.decode(AnyBsonValue.self, from: "{ \"$numberInt\" : \"5\" }").value as? Int).to(equal(int))

        let wrappedInt: Document = ["x": int]
        expect(try encoder.encode(AnyBsonStruct(int))).to(equal(wrappedInt))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedInt).x.value as? Int).to(equal(int))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedInt.canonicalExtendedJSON).x.value as? Int).to(equal(int))

        // int64
        let int64 = Int64(5)

        expect(try decoder.decode(AnyBsonValue.self, from: "{ \"$numberLong\" : \"5\" }").value as? Int64).to(equal(int64))

        let wrappedInt64: Document = ["x": int64]
        expect(try encoder.encode(AnyBsonStruct(Int64(5)))).to(equal(wrappedInt64))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedInt64).x.value as? Int64).to(equal(int64))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedInt64.canonicalExtendedJSON).x.value as? Int64).to(equal(int64))

        // decimal128
        let decimal = Decimal128("1.2E+10")

        expect(try decoder.decode(AnyBsonValue.self, from: "{ \"$numberDecimal\" : \"1.2E+10\" }").value as? Decimal128).to(equal(decimal))

        let wrappedDecimal: Document = ["x": decimal]
        expect(try encoder.encode(AnyBsonStruct(decimal))).to(equal(wrappedDecimal))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedDecimal).x.value as? Decimal128).to(equal(decimal))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedDecimal.canonicalExtendedJSON).x.value as? Decimal128).to(equal(decimal))

        // maxkey
        let maxKey = MaxKey()

        expect(try decoder.decode(AnyBsonValue.self, from: "{ \"$maxKey\" : 1 }").value as? MaxKey).to(equal(maxKey))

        let wrappedMaxKey: Document = ["x": maxKey]
        expect(try encoder.encode(AnyBsonStruct(maxKey))).to(equal(wrappedMaxKey))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedMaxKey).x.value as? MaxKey).to(equal(maxKey))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedMaxKey.canonicalExtendedJSON).x.value as? MaxKey).to(equal(maxKey))

        // minkey
        let minKey = MinKey()

        expect(try decoder.decode(AnyBsonValue.self, from: "{ \"$minKey\" : 1 }").value as? MinKey).to(equal(minKey))

        let wrappedMinKey: Document = ["x": minKey]
        expect(try encoder.encode(AnyBsonStruct(minKey))).to(equal(wrappedMinKey))
        expect(try decoder.decode(AnyBsonStruct.self, from: wrappedMinKey).x.value as? MinKey).to(equal(minKey))
        expect(try decoder.decode(AnyBsonStruct.self,
            from: wrappedMinKey.canonicalExtendedJSON).x.value as? MinKey).to(equal(minKey))
    }

    struct OptionalAnyBson: Codable {
        let val: AnyBsonValue?

        init(_ value: BsonValue?) {
            if let v = value {
                self.val = AnyBsonValue(v)
            } else {
                self.val = nil
            }
        }
    }

    struct OptionalAnyBsonArr {
        let values: [AnyBsonValue?]
    }

    func testOptionalAnyBsonValue() throws {
        let encoder = BsonEncoder()

        let doc: Document = ["y": 1]
        expect(try encoder.encode(OptionalAnyBson(doc))).to(equal(["val": doc]))
        expect(try encoder.encode(OptionalAnyBson(nil))).to(beNil())

        let data = try JSONEncoder().encode(OptionalAnyBson(nil))
        print(String(data: data, encoding: .utf8))
    }
}
