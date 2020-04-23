require "./service_container"

# :nodoc:
class Fiber
  property container : ADI::ServiceContainer { ADI::ServiceContainer.new }
end

# Convenience alias to make referencing `Athena::DependencyInjection` types easier.
alias ADI = Athena::DependencyInjection

# Athena's Dependency Injection (DI) component, `ADI` for short, adds a service container layer to your project.  This allows a project to share useful objects, aka services, throughout the project.
# These objects live in a special struct called the `ADI::ServiceContainer` (SC).  Object instances can be retrieved from the container, or even injected directly into types as a form of constructor DI.
#
# The SC is lazily initialized on fibers; this allows the SC to be accessed anywhere within the project.  The `ADI.container` method will return the SC for the current fiber.
# Since the SC is defined on fibers, it allows for each fiber to have its own SC instance.  This can be useful for web frameworks as each request would have its own SC scoped to that request.
# This however, is up to the each project to implement.
#
# * See `ADI::Register` for documentation on registering services.
# * See `ADI::ServiceContainer` for documentation on working directly with the SC.
#
# NOTE: It is highly recommended to use interfaces as opposed to concrete types when defining the initializers for both services and non-services.
# Using interfaces allows changing the functionality of a type by just changing what service gets injected into it, such as via an alias.
# See this [blog post](https://dev.to/blacksmoke16/dependency-injection-in-crystal-2d66#plug-and-play) for an example of this.
module Athena::DependencyInjection
  # Stores metadata associated with a specific service.
  #
  # The type of the service affects how it behaves within the container.  When a `struct` service is retrieved or injected into a type, it will be a copy of the one in the SC (passed by value).
  # This means that changes made to it in one type, will _NOT_ be reflected in other types.  A `class` service on the other hand will be a reference to the one in the SC.  This allows it
  # to share state between types.
  #
  # ## Fields
  # * `name : String`- The name that should be used for the service.  Defaults to the type's name snake cased.
  # * `public : Bool` - If the service should be directly accessible from the container.  Defaults to `false`.
  # * `tags : Array(String)` - Tags that should be assigned to the service.  Defaults to an empty array.
  #
  # ## Examples
  #
  # ### Without Arguments
  # If the service doesn't have any arguments then the annotation can be applied without any extra options.
  #
  # ```
  # @[ADI::Register]
  # class Store
  #   include ADI::Service
  #
  #   property uuid : String? = nil
  # end
  # ```
  #
  # ### Multiple Services of the Same Type
  # If multiple `ADI::Register` annotations are applied onto the same type, multiple services will be registered based on that type.
  # The name of each service must be explicitly set, otherwise only the last annotation would work.
  #
  # ```
  # @[ADI::Register("GOOGLE", "Google", name: "google")]
  # @[ADI::Register("FACEBOOK", "Facebook", name: "facebook")]
  # struct FeedPartner
  #   include ADI::Service
  #
  #   getter id : String
  #   getter name : String
  #
  #   def initialize(@id : String, @name : String); end
  # end
  # ```
  #
  # ### Service Dependencies
  # Services can be injected into another service by providing the name of the service as a string, prefixed with an `@` symbol.
  # This syntax also works within arrays if you wished to inject a static set of services.
  #
  # ```
  # @[ADI::Register]
  # class Store
  #   include ADI::Service
  #
  #   property uuid : String? = nil
  # end
  #
  # @[ADI::Register("@store")]
  # struct SomeService
  #   include ADI::Service
  #
  #   def initialize(@store : Store); end
  # end
  # ```
  #
  # ### Optional Dependencies
  # Services can be defined with optional dependencies by providing the name of the service as a string, prefixed with an `@?` symbol.
  # Optional dependencies will supply `nil` to the initializer versus raising a compile time error if that service does not exist.
  #
  # ```
  # @[ADI::Register("@?logger")]
  # # Defines an optional dependency for the `logger` service.
  # class Example
  #   include ADI::Service
  #
  #   def initialize(logger : Logger?)
  #     @logger = logger
  #     # You could also instantiate another type if the ivar should remain not nilable
  #     # @logger = logger || SomeDefaultLogger.new
  #   end
  # end
  # ```
  #
  # ### Tagged Services
  # Services can be injected into another service based on a tag by prefixing the name of the tag with an `!` symbol.
  # This will provide an array of all services that have that tag.  It is advised to use this with a parent type/interface to type the ivar with.
  #
  # NOTE: The parent type must also include `ADI::Service`.
  #
  # ```
  # abstract class SomeParentType
  #   include ADI::Service
  # end
  #
  # @[ADI::Register(tags: ["a_type"])]
  # class SomeTypeOne < SomeParentType
  #   include ADI::Service
  # end
  #
  # @[ADI::Register(tags: ["a_type"])]
  # class SomeTypeTwo < SomeParentType
  #   include ADI::Service
  # end
  #
  # @[ADI::Register("!a_type")]
  # struct SomeService
  #   include ADI::Service
  #
  #   def initialize(@types : Array(SomeParentType)); end
  # end
  # ```
  #
  # ### Redefining Services
  # Services can be redefined by registering another service with the same name.  The last defined service with that name will be used.
  # This allows a custom implementation of a service to be used as a dependency to another service, or for injection into a non service type.
  #
  # ```
  # @[ADI::Register]
  # # The original ErrorRenderer, which could originate from an external shard.
  # record ErrorRenderer, value : Int32 = 1 do
  #   include ADI::Service
  #   include ErrorRendererInterface
  # end
  #
  # @[ADI::Register(name: "error_renderer"]
  # # The redefined service, any references to `error_renderer`, or `ErrorRendererInterface` will now resolve to `CustomErrorRenderer`.
  # record CustomErrorRenderer, value : Int32 = 2 do
  #   include ADI::Service
  #   include ErrorRendererInterface
  # end
  # ```
  annotation Register; end

  # Can be applied to a constructor to mark that that method should be used for injection.
  #
  # The main use case for this is if a type has multiple constructors.  Otherwise, the first construtor would be used.
  annotation Inject; end

  # Returns the `ADI::ServiceContainer` for the current fiber.
  def self.container : ADI::ServiceContainer
    Fiber.current.container
  end
end

# # An interface that could have multiple implementations
# module SomeInterface
# end

# @[ADI::Register]
# class FakeService
#   include SomeInterface
# end

# # Allow aliasing a specific interface to a given service
# @[ADI::Register(name: "custom_fake", alias: SomeInterface)]
# class CustomFooFakeService
#   include SomeInterface
# end

# # Auto resolves based on an interface but supply explicit arg
# @[ADI::Register(_name: "JIM")]
# class Bar
#   def initialize(@asdf : SomeInterface, @name : String); end
# end

# # Auto resolves based on type
# @[ADI::Register]
# class FooBar
#   def initialize(@obj : Foo); end
# end

# # Scalar arguments
# @[ADI::Register(1, "fred", false)]
# class Foo
#   def initialize(@id : Int32, @name : String, @active : Bool); end
# end

# PARTNER_TAG = "partner"

# # Multiple services based on same class
# @[ADI::Register(1, "Google", name: "google", tags: [{name: PARTNER_TAG, priority: 5}])]
# @[ADI::Register(2, "Facebook", name: "facebook", tags: [PARTNER_TAG])]
# @[ADI::Register(3, "Yahoo", name: "yahoo", tags: [{name: PARTNER_TAG, priority: 10}])]
# @[ADI::Register(4, "Microsoft", name: "microsoft", tags: [PARTNER_TAG])]
# struct FeedPartner
#   def initialize(@id : Int32, @name : String); end
# end

# # Resolve all services with the given tag
# @[ADI::Register("!partner", public: true)]
# class PartnerManager
#   def initialize(@partners : Array(FeedPartner))
#   end
# end

# @[ADI::Register(public: true, generics: {Int32, Bool}, name: "int_service")]
# @[ADI::Register(public: true, generics: {Float64, Bool}, name: "float_service")]
# struct GenericService(T, B)
#   def type
#     {T, B}
#   end
# end

# cont = ADI::ServiceContainer.new

# pp cont.int_service.type
# pp cont.float_service.type

# module TransformerInterface
#   abstract def transform(value : String) : String
# end

# module Foo; end

# @[ADI::Register]
# struct ReverseTransformer
#   include TransformerInterface

#   def transform(value : String) : String
#     value.reverse
#   end
# end

# @[ADI::Register]
# struct ShoutTransformer
#   include TransformerInterface

#   def transform(value : String) : String
#     value.upcase
#   end
# end

# @[ADI::Register(TransformerInterface, public: true)]
# class Client
#   def initialize(transformer : TransformerInterface)
#     @transformer = transformer
#   end

#   def call(value : String)
#     pp @transformer.transform value.to_s
#   end
# end

# ADI.container.client.call "foo bar"
# class MissingService
# end

# @[ADI::Register]
# class Klass
#   def initialize(@service : MissingService); end
# end

# pp ADI::ServiceContainer.new
