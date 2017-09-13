import Foundation

public typealias Listener = (Subscription, [Any?]) -> Void

public protocol Initializable {
  init()
  init(_ args: [String:Any?])
}

public protocol ContextAware {
  var __context__: Context { get set }
  var __subContext__: Context { get }
}

public protocol Axiom {
  var name: String { get }
}

class ListenerList {
  var next: ListenerList?
  var prev: ListenerList?
  lazy var children: [String:ListenerList] = [:]
  var listener: Listener?
  var sub: Subscription?
}

public protocol PropertyInfo: Axiom {
  var classInfo: ClassInfo { get }
  var transient: Bool { get }
  var view: ClassInfo? { get }
  var label: String { get }
  var visibility: Visibility { get }
  var jsonParser: Parser? { get }
  func set(_ obj: FObject, value: Any?)
  func get(_ obj: FObject) -> Any? // TODO rename to f?
  func compareValues(_ v1: Any?, _ v2: Any?) -> Int
}

extension PropertyInfo {
  public func toJSON(outputter: Outputter, out: inout String, value: Any?) {
    outputter.output(&out, value)
  }
  public func compare(_ o1: FObject, _ o2: FObject) -> Int {
    let v1 = get(o1) as AnyObject?
    let v2 = get(o2) as AnyObject?
    if v1 === v2 { return 0 }
    if v1 == nil && v2 == nil { return 0 }
    if v1 == nil { return -1 }
    if v2 == nil { return 1 }
    return compareValues(v1, v2)
  }
}

public class Action: Axiom {
  public var name: String = ""
  public var label: String = ""
  public func call(_ obj: FObject) {
    obj.callAction(key: name)
  }
}

public class MethodArg {
  public var name: String = ""
}

public protocol MethodInfo: Axiom {
  var args: [MethodArg] { get }
}
extension MethodInfo {
  public func call(_ obj: FObject, args: [Any?]) throws -> Any? {
    let callback = obj.getSlot(key: name)!.swiftGet() as! ([Any?]) throws -> Any?
    return try callback(args)
  }
}

public class Context {
  public static let GLOBAL = Context()

  private lazy var classMap: [String:ClassInfo] = [:]
  public func registerClass(cls: ClassInfo) {
    classMap[cls.id] = cls
  }
  public func lookup(_ id: String) -> ClassInfo? {
    return classMap[id]
  }

  public func create(cls: ClassInfo, args: [String:Any?] = [:]) -> FObject {
    if var multiton = cls as? Multiton, let key = args[multiton.multitonProperty.name] as? String {
      if let value = multiton.multitonMap[key] {
        return value
      } else {
        let value = create(type: cls.cls, args: args) as! FObject
        multiton.multitonMap[key] = value
        return value
      }
    } else {
      return create(type: cls.cls, args: args) as! FObject
    }
  }

  // TODO is this method needed?
  private func create(type: Any, args: [String:Any?] = [:]) -> Any? {
    var o: Any? = nil
    if let t = type as? Initializable.Type {
      o = t.init(args)
    }
    if var o = o as? ContextAware {
      o.__context__ = self
    }
    return o
  }

  private var slotMap: [String:Slot] = [:]
  public subscript(key: String) -> Any? {
    if let slot = slotMap[key] {
      return slot
    } else if let slot = slotMap[toSlotName(name: key)] {
      return slot.swiftGet()
    }
    return nil
  }
  private func toSlotName(name: String) -> String { return name + "$" }
  public func createSubContext(args: [String:Any?] = [:]) -> Context {
    var slotMap = self.slotMap
    for (key, value) in args {
      let slotName = toSlotName(name: key)
      if let slot = value as AnyObject as? Slot {
        slotMap[slotName] = slot
      } else {
        slotMap[slotName] = ConstantSlot(["value": value])
      }
    }

    let subContext = Context()
    subContext.slotMap = slotMap
    subContext.classMap = classMap
    return subContext
  }
}

public protocol ClassInfo {
  var id: String { get }
  var label: String { get }
  var parent: ClassInfo? { get }
  var ownAxioms: [Axiom] { get }
  var cls: Any { get }
}

extension ClassInfo {
  /*
  func create(_ args: [String:Any?] = [:], x: Context = Context.GLOBAL) -> FObject {
    if var multiton = self as? Multiton, let key = args[multiton.multitonProperty.name] as? String {
      if let value = multiton.multitonMap[key] {
        return value
      } else {
        let value = x.create(type: cls, args: args) as! FObject
        multiton.multitonMap[key] = value
        return value
      }
    } else {
      return x.create(type: cls, args: args) as! FObject
    }
  }
  */
  var axioms: [Axiom] {
    get {
      var curCls: ClassInfo? = self
      var axioms: [Axiom] = []
      while curCls != nil {
        axioms += curCls!.ownAxioms
        curCls = curCls!.parent
      }
      return axioms
    }
  }
  func ownAxioms<T>(byType type: T.Type) -> [T] {
    var axs: [T] = []
    for axiom in ownAxioms {
      if let axiom = axiom as? T {
        axs.append(axiom)
      }
    }
    return axs
  }
  func axioms<T>(byType type: T.Type) -> [T] {
    var axs: [T] = []
    for axiom in axioms {
      if let axiom = axiom as? T {
        axs.append(axiom)
      }
    }
    return axs
  }
  func axiom(byName name: String) -> Axiom? {
    for axiom in axioms {
      if axiom.name == name { return axiom }
    }
    return nil
  }
}

public protocol Multiton {
  var multitonProperty: PropertyInfo { get }
  var multitonMap: [String:FObject] { get set }
}

public class Subscription {
  private var detach_: (() -> Void)?
  init(detach: @escaping () ->Void) {
    self.detach_ = detach
  }
  func detach() {
    detach_?()
    detach_ = nil
  }
}

public protocol FObject: class {
  func ownClassInfo() -> ClassInfo
  func sub(topics: [String], listener l: @escaping Listener) -> Subscription
  func set(key: String, value: Any?)
  func get(key: String) -> Any?
  func getSlot(key: String) -> Slot?
  func hasOwnProperty(_ key: String) -> Bool
  func clearProperty(_ key: String)
  func callAction(key: String)
  func compareTo(_ data: FObject?) -> Int
  func onDetach(_ sub: Subscription)
  func detach()
  init(_ args: [String:Any?])
}

// TODO figure out how to make FObjects implement Comparable.
/*
extension FObject {
  public static func < (lhs: FObject, rhs: FObject) -> Bool { return lhs.compareTo(rhs) < 0 }
  public static func == (lhs: FObject, rhs: FObject) -> Bool { return lhs.compareTo(rhs) == 0 }
  public static func > (lhs: FObject, rhs: FObject) -> Bool { return lhs.compareTo(rhs) > 1 }
}
*/

public class AbstractFObject: NSObject, FObject, Initializable, ContextAware {
  public func ownClassInfo() -> ClassInfo { fatalError() }

  public var __context__: Context = Context.GLOBAL {
    didSet {
      self.__subContext__ = self.__context__.createSubContext(args: self._createExports_())
    }
  }
  lazy private(set) public var __subContext__: Context = {
    return self.__context__.createSubContext(args: self._createExports_())
  }()

  func _createExports_() -> [String:Any?] {
    return [:]
  }

  lazy var listeners: ListenerList = ListenerList()

  private static var classInfo_: ClassInfo = {
    class ClassInfo_: ClassInfo {
      lazy var cls: Any = AbstractFObject.self
      lazy var id: String = "FObject"
      lazy var label: String = "FObject"
      lazy var parent: ClassInfo? = nil
      lazy var ownAxioms: [Axiom] = []
    }
    return ClassInfo_()
  }()

  public class func classInfo() -> ClassInfo { return AbstractFObject.classInfo_ }

  public func set(key: String, value: Any?) {}
  public func get(key: String) -> Any? { return nil }
  public func getSlot(key: String) -> Slot? { return nil }
  public func hasOwnProperty(_ key: String) -> Bool { return false }
  public func clearProperty(_ key: String) {}

  public func onDetach(_ sub: Subscription) {
    _ = self.sub(topics: ["detach"]) { (s, _) in
      s.detach()
      sub.detach()
    }
  }

  public func detach() {
    _ = pub(["detach"])
    detachListeners(listeners: listeners)
  }

  public func sub(
    topics: [String] = [],
    listener l: @escaping Listener) -> Subscription {

    var listeners = self.listeners
    for topic in topics {
      if listeners.children[topic] == nil {
        listeners.children[topic] = ListenerList()
      }
      listeners = listeners.children[topic]!
    }

    let node = ListenerList()
    node.next = listeners.next
    node.prev = listeners
    node.listener = l
    node.sub = Subscription(detach: {
      _ = self
      node.next?.prev = node.prev
      node.prev?.next = node.next
      node.listener = nil
      node.next = nil
      node.prev = nil
      node.sub = nil
    })

    listeners.next?.prev = node
    listeners.next = node

    return node.sub!
  }

  func hasListeners(_ args: [Any]) -> Bool {
    var listeners: ListenerList? = self.listeners
    var i = 0
    while listeners != nil {
      if listeners?.next != nil { return true }
      if i == args.count { return false }
      if let p = args[i] as? String {
        listeners = listeners?.children[p]
        i += 1
      } else {
        break
      }
    }
    return false
  }

  private func notify(listeners: ListenerList?, args: [Any]) -> Int {
    var count = 0
    var l = listeners
    while l != nil {
      let listener = l!.listener!
      let sub = l!.sub!
      l = l!.next
      listener(sub, args)
      count += 1
    }
    return count
  }

  public func pub(_ args: [Any]) -> Int {
    var listeners: ListenerList = self.listeners
    var count = notify(listeners: listeners.next, args: args)
    for arg in args {
      guard let key = arg as? String else { break }
      if listeners.children[key] == nil { break }
      listeners = listeners.children[key]!
      count += notify(listeners: listeners.next, args: args)
    }
    return count
  }

  public func compareTo(_ data: FObject?) -> Int {
    if self === data { return 0 }
    if data == nil { return 1 }
    let data = data!
    if ownClassInfo().id != data.ownClassInfo().id {
      return ownClassInfo().id > data.ownClassInfo().id ? 1 : -1
    }
    for props in data.ownClassInfo().axioms(byType: PropertyInfo.self) {
      let diff = props.compare(self, data)
      if diff != 0 { return diff }
    }
    return 0
  }

  public func callAction(key: String) { }

  public override required init() {
    super.init()
    __foamInit__()
  }

  public required init(_ args: [String:Any?]) {
    super.init()
    for (key, value) in args {
      self.set(key: key, value: value)
    }
    __foamInit__()
  }

  public required init(X x: Context) {
    super.init()
    __foamInit__()
    __context__ = x
  }

  public required init(_ args: [String:Any?], _ x: Context) {
    super.init()
    for (key, value) in args {
      self.set(key: key, value: value)
    }
    __foamInit__()
    __context__ = x
  }

  func __foamInit__() {}

  private func detachListeners(listeners: ListenerList?) {
    var l = listeners
    while l != nil {
      l!.sub?.detach()
      for child in l!.children.values {
        detachListeners(listeners: child)
      }
      l = l!.next
    }
  }

  deinit {
    detach()
  }
}

struct FOAM_utils {
  public static func equals(_ o1: Any?, _ o2: Any?) -> Bool {
    let a = o1 as AnyObject?
    let b = o2 as AnyObject?
    if a === b { return true }
    if a != nil { return a!.isEqual(b) }
    return false
  }
  static var nextId = 1
  static func next$UID() -> Int {
    var id: Int?
    DispatchQueue(label: "FObjectUIDLock", attributes: []).sync {
      id = nextId
      nextId += 1
    }
    return id!
  }
}

public class Reference<T> {
  var value: T
  init(value: T) { self.value = value }
}

extension String {
  func char(at: Int) -> Character {
    return self[index(startIndex, offsetBy: at)]
  }
  func index(of: Character) -> Int {
    if let r = range(of: of.description) {
      return distance(from: startIndex, to: r.lowerBound)
    }
    return -1
  }
}

extension Character {
  func isDigit() -> Bool {
    return "0"..."9" ~= self
  }
}

public class ModelParserFactory {
  private static var parsers: [String:Parser] = [:]
  public static func getInstance(_ cls: ClassInfo) -> Parser {
    if let p = parsers[cls.id] { return p }
    let parser = buildInstance(cls)
    parsers[cls.id] = parser
    return parser
  }
  private static func buildInstance(_ info: ClassInfo) -> Parser {
    var parsers = [Parser]()
    for p in info.axioms(byType: PropertyInfo.self) {
      if p.jsonParser != nil {
        parsers.append(PropertyParser(["property": p]))
      }
    }
    return Repeat0([
      "delegate": Seq0(["parsers": [
        Whitespace(),
        Alt(["parsers": parsers])
      ]]),
      "delim": Literal(["string": ","]),
    ])
  }
}

public protocol FOAM_enum {
  var ordinal: Int { get }
  var name: String { get }
  var label: String { get }
}

public class FoamError: Error {
  var obj: Any?
  init(_ obj: Any?) { self.obj = obj }
}

public class Future<T> {
  var set: Bool = false
  var value: T?
  var error: Error?
  var semaphore = DispatchSemaphore(value: 0)
  var numWaiting = 0
  public func get() throws -> T? {
    if !set {
      numWaiting += 1
      semaphore.wait()
    }
    if error != nil {
      throw error!
    }
    return value
  }
  public func set(_ value: T?) {
    self.value = value
    set = true
    for _ in 0...numWaiting {
      semaphore.signal()
    }
  }
  public func error(_ value: Error?) {
    self.error = value
    set = true
    for _ in 0...numWaiting {
      semaphore.signal()
    }
  }
}