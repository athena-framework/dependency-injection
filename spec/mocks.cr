class UnknownService
end

abstract class FakeServices
  include ADI::Service
end

@[ADI::Register]
class FakeService < FakeServices
  include ADI::Service
end

@[ADI::Register(name: "custom_fake")]
class CustomFooFakeService < FakeServices
  include ADI::Service
end

@[ADI::Register([1, 2, 3], ["@custom_fake"], {id: 99_i64, active: true}, public: true)]
class StaticArgs
  include ADI::Service

  getter scalar_arr, service_arr, named_tuple_arg

  def initialize(@scalar_arr : Array(Int32), @service_arr : Array(FakeServices), @named_tuple_arg : NamedTuple(id: Int64, active: Bool))
  end
end

@[ADI::Register("GOOGLE", "Google", name: "google", tags: ["feed_partner", "partner"])]
@[ADI::Register("FACEBOOK", "Facebook", name: "facebook", tags: ["partner"])]
struct FeedPartner
  include ADI::Service

  getter id : String
  getter name : String

  def initialize(@id : String, @name : String); end
end

@[ADI::Register("!partner")]
class PartnerManager
  include ADI::Service

  getter partners

  def initialize(@partners : Array(FeedPartner))
  end
end

class PartnerParamConverter
  include ADI::Injectable

  getter manager

  def initialize(@manager : PartnerManager); end
end

@[ADI::Register(public: true)]
class Store
  include ADI::Service

  property name : String = "Jim"
end

class FakeStore < Store
  property name : String = "TEST"
end

class SomeClass
  include ADI::Injectable

  getter store : Store

  def initialize(@store : Store); end
end

class OtherClass
  include ADI::Injectable

  getter store : Store
  getter id : String

  def initialize(@store : Store, @id : String); end
end

@[ADI::Register("@blah", "a_string", "@a_service")]
class AService2
  include ADI::Service

  getter blah : Blah
  getter foo : String
  getter ase : AService

  def initialize(@blah : Blah, @foo : String, @ase : AService); end
end

@[ADI::Register("@blah", "@some_service")]
class AService
  include ADI::Service

  def initialize(@blah : Blah, @foo : Foo); end
end

@[ADI::Register("@some_service", 99_i64)]
class Blah
  include ADI::Service

  getter foo : Foo
  getter val : Int64

  def initialize(@foo : Foo, @val : Int64); end
end

@[ADI::Register(name: "some_service")]
class Foo
  include ADI::Service

  property name = "Bob"
end

class FooBar
  include ADI::Injectable

  getter serv : AService2

  def initialize(@serv : AService2); end
end

# Overriding services

@[ADI::Register(public: true)]
record ErrorRenderer, value : Int32 = 1 do
  include ADI::Service
end

@[ADI::Register(name: "error_renderer", public: true)]
record CustomErrorRenderer, value : Int32 = 2 do
  include ADI::Service
end

# Optional Dependencies

class MissingService; end

@[ADI::Register("@?missing_service", public: true)]
class OptionalMissing
  include ADI::Service

  getter service : MissingService?

  def initialize(@service : MissingService?); end
end

@[ADI::Register]
class Logger
  include ADI::Service
end

@[ADI::Register("@?logger", public: true)]
class OptionalRegistered
  include ADI::Service

  getter logger : Logger?

  def initialize(@logger : Logger?); end
end
