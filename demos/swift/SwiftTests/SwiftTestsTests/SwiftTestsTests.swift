import XCTest
@testable import SwiftTests

class SwiftTestsTests: XCTestCase {

  let x = Context.GLOBAL

  override func setUp() {
    super.setUp()
  }

  override func tearDown() {
    super.tearDown()
  }

  func testListen() {
    let test = Test()
    var numPubs = 0
    _ = test.sub(listener: { (sub: Subscription, args: [Any?]) -> Void in
      numPubs += 1
      sub.detach()
    })

    var numPubs2 = 0
    _ = test.sub(listener: { (sub: Subscription, args: [Any?]) -> Void in
      numPubs2 += 1
    })

    var numPubs3 = 0
    _ = test.lastName$.swiftSub({ (sub: Subscription, args: [Any?]) -> Void in
      numPubs3 += 1
    })

    test.firstName = "1"
    test.lastName = "2"
    XCTAssertEqual(test.methodWithAnArgAndReturn("3"), "Hello there 3 LASTNAME")

    XCTAssertEqual(numPubs, 1)
    XCTAssertEqual(numPubs2, 4) // Each set to first or last name triggers another set.
    XCTAssertEqual(numPubs3, 1)

    test.detach()
  }

  func testFollow() {
    let o1 = Test(["firstName": "A"])
    let o2 = Test(["firstName$": o1.firstName$])
    XCTAssertEqual(o2.firstName, "A")
    o2.firstName = "B"
    XCTAssertEqual(o1.firstName, "B")
    o1.detach()
    o2.detach()
  }

  func testObjectCreationPerformance() {
    self.measure {
      for _ in 1...1000 {
        _ = Test()
      }
    }
  }

  func testCharsParse() {
    let parser = Alt([
      "parsers": [
        Chars(["chars": "A"]),
        Chars(["chars": " "]),
      ],
    ])
    var ps: PStream! = StringPStream(["str": "A string"])

    // Parsing first character.
    ps = parser.parse(ps, x)
    XCTAssertNotNil(ps)

    // Parsing second character.
    ps = parser.parse(ps, x)
    XCTAssertNotNil(ps)

    // Parsing third character.
    ps = parser.parse(ps, x)
    XCTAssertNil(ps)
  }

  func testAnyCharParse() {
    let parser = AnyChar()
    var ps: PStream! = StringPStream(["str": "123"])

    ps = parser.parse(ps, x) // 1
    XCTAssertNotNil(ps)

    ps = parser.parse(ps, x) // 2
    XCTAssertNotNil(ps)

    ps = parser.parse(ps, x) // 3
    XCTAssertNotNil(ps)

    ps = parser.parse(ps, x) // Error
    XCTAssertNil(ps)
  }


  func testLiteralParse() {
    let parser = Literal(["string": "myLiteral"])
    XCTAssertNil(parser.parse(StringPStream(["str": "hello"]), x))
    XCTAssertNotNil(parser.parse(StringPStream(["str": "myLiteralHello"]), x))
  }

  func testNotCharsParse() {
    let parser = NotChars(["chars": "ABC"])
    XCTAssertNil(parser.parse(StringPStream(["str": "AHello"]), x))
    XCTAssertNotNil(parser.parse(StringPStream(["str": "Hello"]), x))
  }

  func testRepeat() {
    let parser = Repeat([
      "delegate": Chars(["chars": "A"]),
      "delim": Chars(["chars": ","]),
      "min": 3,
      "max": 5,
    ])
    XCTAssertNil(parser.parse(StringPStream(["str": "A,A"]), x))
    XCTAssertNotNil(parser.parse(StringPStream(["str": "A,A,A"]), x))
    XCTAssertNotNil(parser.parse(StringPStream(["str": "A,A,A,A"]), x))
    XCTAssertNotNil(parser.parse(StringPStream(["str": "A,A,A,A,A"]), x))
    XCTAssertEqual(parser.parse(
        StringPStream(["str": "A,A,A"]), x)!.value()! as! [Character],
        ["A","A","A"] as [Character])
  }

  func testRepeat0() {
    let parser = Repeat0([
      "delegate": Chars(["chars": "A"]),
      "delim": Chars(["chars": ","]),
      "min": 3,
      "max": 5,
      ])
    XCTAssertNil(parser.parse(StringPStream(["str": "A,A"]), x))
    XCTAssertNotNil(parser.parse(StringPStream(["str": "A,A,A"]), x))
    XCTAssertNotNil(parser.parse(StringPStream(["str": "A,A,A,A"]), x))
    XCTAssertNotNil(parser.parse(StringPStream(["str": "A,A,A,A,A"]), x))
    XCTAssertEqual(parser.parse(
        StringPStream(["str": "A,A,A,A,A"]), x)!.value()! as! Character,
        "A")
  }

  func testSeq() {
    let parser = Seq([
      "parsers": [
        Chars(["chars": "A"]),
        Chars(["chars": "B"]),
      ]
    ])
    XCTAssertNil(parser.parse(StringPStream(["str": "AAB"]), x))
    XCTAssertEqual(
      parser.parse(StringPStream(["str": "ABB"]), x)!.value()! as! [Character],
      ["A", "B"])
  }

  func testSeq0() {
    let parser = Seq0([
      "parsers": [
        Chars(["chars": "A"]),
        Chars(["chars": "B"]),
      ]
    ])
    XCTAssertNil(parser.parse(StringPStream(["str": "AAB"]), x))
    XCTAssertEqual(parser.parse(StringPStream(["str": "ABC"]), x)!.value()! as! Character, "B")
  }

  func testSeq1() {
    let parser = Seq1([
      "parsers": [
        Chars(["chars": "A"]),
        Chars(["chars": "B"]),
      ],
      "index": 0,
    ])
    XCTAssertNil(parser.parse(StringPStream(["str": "AAB"]), x))
    XCTAssertEqual(parser.parse(StringPStream(["str": "ABC"]), x)!.value()! as! Character, "A")
  }

  func testSeq2() {
    let parser = Seq2([
      "parsers": [
        Chars(["chars": "A"]),
        Chars(["chars": "B"]),
        Chars(["chars": "C"]),
      ],
      "index1": 0,
      "index2": 2,
    ])
    XCTAssertNil(parser.parse(StringPStream(["str": "AB"]), x))
    XCTAssertEqual(
      parser.parse(StringPStream(["str": "ABCD"]), x)!.value()! as! [Character],
      ["A", "C"])
  }

  func testSubstring() {
    let parser = Substring([
      "delegate": Repeat([
        "delegate": Chars(["chars": "BA"]),
      ])
    ])
    XCTAssertEqual(parser.parse(StringPStream(["str": "ABCDEFG"]), x)!.value()! as! String, "AB")
  }

  func testAnyKeyParser() {
    let parser = AnyKeyParser()
    XCTAssertEqual(parser.parse(StringPStream(["str": "KEY"]), x)!.value()! as! String, "KEY")
    XCTAssertEqual(parser.parse(StringPStream(["str": "\"KEY\": "]), x)!.value()! as! String, "KEY")
  }

  func testFloatParser() {
    let parser = FloatParser()
    XCTAssertNil(parser.parse(StringPStream(["str": "KEY"]), x))
    XCTAssertEqual(parser.parse(StringPStream(["str": "0.1"]), x)!.value()! as! Float, 0.1)
    XCTAssertEqual(parser.parse(StringPStream(["str": "1."]), x)!.value()! as! Float, 1.0)
    XCTAssertEqual(parser.parse(StringPStream(["str": "-0.1123"]), x)!.value()! as! Float, -0.1123)
    XCTAssertEqual(parser.parse(StringPStream(["str": "-50"]), x)!.value()! as! Float, -50.0)
  }

  func testIntParser() {
    let parser = IntParser()
    XCTAssertNil(parser.parse(StringPStream(["str": "KEY"]), x))
    XCTAssertEqual(parser.parse(StringPStream(["str": "0.1"]), x)!.value()! as! Int, 0)
    XCTAssertEqual(parser.parse(StringPStream(["str": "1."]), x)!.value()! as! Int, 1)
    XCTAssertEqual(parser.parse(StringPStream(["str": "-0.1123"]), x)!.value()! as! Int, 0)
    XCTAssertEqual(parser.parse(StringPStream(["str": "-50"]), x)!.value()! as! Int, -50)
  }

  func testFObjectParse() {
    let x = Context.GLOBAL.createSubContext(args: ["X": Context.GLOBAL])
    let ps = FObjectParser().parse(
        StringPStream(["str": "{class:'Test', prevFirstName: \"MY_PREV_NAME\"}"]), x)
    XCTAssertTrue(ps!.value() is Test)
    XCTAssertEqual((ps!.value() as! Test).prevFirstName, "MY_PREV_NAME")
  }

  func testToJSON() {
    let t = Test()
    t.prevFirstName = "MY_PREV_NAME"
    t.boolProp = false
    t.intProp = 34
    XCTAssertEqual(Outputter().swiftStringify(t),
    "{\"class\":\"Test\",\"intProp\":34,\"boolProp\":false,\"prevFirstName\":\"MY_PREV_NAME\"}")
  }

  func testExpression() {
    let t = Test()
    t.firstName = "Mike"
    t.lastName = "C"
    XCTAssertEqual(t.exprProp, "Mike C")
    t.lastName = "D"
    XCTAssertEqual(t.exprProp, "Mike D")

    t.exprProp = "OVERRIDE"
    XCTAssertEqual(t.exprProp, "OVERRIDE")
    t.firstName = "Nope"
    XCTAssertEqual(t.exprProp, "OVERRIDE")
    t.detach()
  }

  func testCompare() {
    let t1 = Test()
    let t2 = Test()
    XCTAssertEqual(t1.compareTo(t2), 0)
    t1.firstName = "NOT T2"
    XCTAssertEqual(t1.compareTo(t2), 1)
    t2.firstName = "NOT T2"
    XCTAssertEqual(t1.compareTo(t2), 0)
    t1.clearProperty("firstName")
    XCTAssertEqual(t1.compareTo(t2), -1)
  }

  func testArrayDao() {
    let dao = ArrayDAO([
      "of": Test.classInfo(),
      "primaryKey": Test.FIRST_NAME,
    ])
    let t1 = Test([
      "firstName": "Mike",
    ])
    XCTAssertEqual(t1, dao.put(t1) as? Test)
    XCTAssertEqual(dao.dao as! [Test], [t1])
    XCTAssertEqual(t1, dao.put(t1) as? Test)
    XCTAssertEqual(dao.dao as! [Test], [t1])

    let t2 = Test([
      "firstName": "Mike",
    ])
    XCTAssertEqual(t2, dao.put(t2) as? Test)
    XCTAssertEqual(dao.dao as! [Test], [t2])

    t1.firstName = "Mike2"
    XCTAssertEqual(t1, dao.put(t1) as? Test)
    XCTAssertEqual(dao.dao as! [Test], [t2, t1])

    XCTAssertEqual(t1, dao.find(t1.firstName) as? Test)

    let tToRemove = Test(["firstName": "Mike2"])
    let tRemoved = dao.remove(tToRemove) as? Test
    XCTAssertNotEqual(tRemoved, tToRemove)
    XCTAssertEqual(tRemoved, t1)

    let sink = dao.select() as! ArraySink
    XCTAssertEqual(sink.dao as! [Test], [t2])
  }

  func testDaoListen() {
    let dao = ArrayDAO([
      "of": Test.classInfo(),
      "primaryKey": Test.FIRST_NAME,
    ])

    let sink = ArraySink()
    let detach = dao.listen(sink)

    let t1 = dao.put(Test(["firstName": "A"])) as! Test
    XCTAssertEqual(sink.dao as! [Test], [t1])

    let t2 = dao.put(Test(["firstName": "B"])) as! Test
    XCTAssertEqual(sink.dao as! [Test], [t1, t2])

    _ = dao.remove(Test(["firstName": "B"])) as! Test
    XCTAssertEqual(sink.dao as! [Test], [t1])

    detach.detach()
    _ = dao.put(Test(["firstName": "C"]))
    XCTAssertEqual(sink.dao.count, 1)
  }

  func testDaoSkipLimitSelect() {
    let dao = ArrayDAO([
      "of": Test.classInfo(),
      "primaryKey": Test.FIRST_NAME,
    ])

    for i in 1...10 {
      _ = dao.put(Test(["firstName": i]))
    }

    let sink = dao.select(skip: 2, limit: 5) as! ArraySink
    XCTAssertEqual(sink.dao.count, 5)
    XCTAssertEqual("3", (sink.dao[0] as! Test).firstName)
  }

  func testExpressionSlot() {
    let o = Test()
    let slot = ExpressionSlot()
    slot.args = [o.firstName$, o.lastName$]
    slot.code = { args in
      return (args[0] as! String) + " " + (args[1] as! String)
    }

    o.firstName = "Mike"
    o.lastName = "C"
    XCTAssertEqual(slot.swiftGet() as! String, "Mike C")

    o.lastName = "D"
    XCTAssertEqual(slot.swiftGet() as! String, "Mike D")

    o.detach()
    slot.detach()
  }

  func testMemLeaks() {
    for _ in 1...5000 {
      testFollow()
      testListen()
      testExpression()
      testExpressionSlot()
      testSubSlot()
      testSubSlot2()
    }
  }

  func testHasOwnProperty() {
    let o = Test()
    o.firstName = "Mike"
    o.lastName = "C"
    XCTAssertEqual(o.exprProp, "Mike C")
    XCTAssertFalse(o.hasOwnProperty("exprProp"))
  }

  func testSwiftSubFire() {
    let o = Tabata()

    var calls = 0
    let sub = o.seconds$.swiftSub { (_, _) in
      calls += 1
    }

    XCTAssertEqual(calls, 0)
    o.seconds += 1
    XCTAssertEqual(calls, 1)

    sub.detach()
  }

  func testSubSlot() {
    let t = Test()
    let t2 = Test()
    t2.firstName = "YO"
    t.anyProp = t2

    let s = t.anyProp$.dot("firstName")
    XCTAssertEqual(s.swiftGet() as? String, "YO")

    var i = 0
    _ = s.swiftSub { (_, _) in
      i += 1
      XCTAssertEqual(s.swiftGet() as? String, "YO2")
    }
    t2.firstName = "YO2"
    XCTAssertEqual(s.swiftGet() as? String, "YO2")
    XCTAssertEqual(i, 1)

    s.detach()
    t.detach()
    t2.detach()
  }

  func testSubSlot2() {
    let t = Test(["firstName": "a"])

    var slot = 0
    let s1 = t.firstName$.swiftSub { (_, _) in
      slot += 1
    }

    var subSlot = 0
    let t2 = Test(["anyProp": t])
    let s2 = t2.anyProp$.dot("firstName").swiftSub { (_, _) in
      subSlot += 1
    }

    XCTAssertEqual(t2.anyProp$.dot("firstName").swiftGet() as! String, "a")
    XCTAssertEqual(slot, 0)
    XCTAssertEqual(subSlot, 0)

    t.firstName = "B"

    XCTAssertEqual(t2.anyProp$.dot("firstName").swiftGet() as! String, "B")
    XCTAssertEqual(slot, 1)
    XCTAssertEqual(subSlot, 1)

    s1.detach()
    s2.detach()
    t.detach()
    t2.detach()
  }

  func testRPCBoxSuccess() {
    let rpcBox = RPCReturnBox()

    let sem = DispatchSemaphore(value: 0)

    var dispatched = false
    DispatchQueue(label: "TestDispatch").async {
      let msg = try? rpcBox.future.get() as! String
      dispatched = true
      XCTAssertEqual(msg, "Hello there")
      sem.signal()
    }

    let msg = Message(["object": RPCReturnMessage(["data": "Hello there"])])
    XCTAssertFalse(dispatched)
    try! rpcBox.send(msg)
    sem.wait()
    XCTAssertTrue(dispatched)
  }

  func testRPCBoxError() {
    let rpcBox = RPCReturnBox()

    let sem = DispatchSemaphore(value: 0)

    var dispatched = false
    DispatchQueue(label: "TestDispatch").async {
      do {
        _ = try rpcBox.future.get() as! String
      } catch let e {
        let e = e as! FoamError
        dispatched = true
        XCTAssertEqual(e.obj as? String, "Hello there")
        sem.signal()
      }
    }

    let msg = Message(["object": "Hello there"])
    XCTAssertFalse(dispatched)
    try! rpcBox.send(msg)
    sem.wait()
    XCTAssertTrue(dispatched)
  }

  func testClientBoxRegistry() {
    let boxContext = BoxContext()
    let X = boxContext.__subContext__

    let outputter = X.create(cls: Outputter.classInfo()) as! Outputter
    let parser = X.create(cls: FObjectParser.classInfo()) as! FObjectParser

    class TestBox: Box {
      var o: Any?
      func send(_ msg: Message) throws {
        o = msg.object
      }
    }
    let testBox = TestBox()
    let registeredBox =
        (boxContext.registry as! BoxRegistryBox).register("TestBox", nil, testBox) as? SubBox

    _ = (boxContext.registry as! BoxRegistryBox).register("", nil, boxContext.registry as! BoxRegistryBox) as? SubBox
    boxContext.root = boxContext.registry

    class RegistryDelegate: Box {
      var outputter: Outputter
      var parser: FObjectParser
      var registry: Box
      init(registry: Box, outputter: Outputter, parser: FObjectParser) {
        self.registry = registry
        self.outputter = outputter
        self.parser = parser
      }
      func send(_ msg: Message) throws {
        let str = outputter.swiftStringify(msg)
        let obj = parser.parse(
          StringPStream(["str": str]),
          Context.GLOBAL.createSubContext(args: ["X": parser.__subContext__]))
        try registry.send(obj?.value() as! Message)
      }
    }

    let clientBoxRegistry = ClientBoxRegistry(X: X)
    clientBoxRegistry.delegate =
        RegistryDelegate(registry: boxContext.registry!, outputter: outputter, parser: parser)

    do {
      let box = try clientBoxRegistry.doLookup("TestBox") as? SubBox
      XCTAssertNotNil(box)
      XCTAssertTrue(registeredBox === box)
      try? box?.send(Message(["object": "HELLO"]))
      XCTAssertEqual(testBox.o as? String, "HELLO")
    } catch let e {
      fatalError()
    }
  }

  func testHTTPBox() {
    let boxContext = BoxContext()
    let X = boxContext.__subContext__

    let httpBox = HTTPBox()
    httpBox.url = "http://google.com"

    let msg = Message()
    msg.object = "HELLO WOLRD"

    try? httpBox.send(msg)
  }
}