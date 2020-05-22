require "./service_container"

# :nodoc:
class Fiber
  property container : ADI::ServiceContainer { ADI::ServiceContainer.new }
end

# Convenience alias to make referencing `Athena::DependencyInjection` types easier.
alias ADI = Athena::DependencyInjection

# Athena's Dependency Injection (DI) component, `ADI` for short, adds a service container layer to your project.  This useful objects, aka services, to be shared throughout the project.
# These objects live in a special class called the `ADI::ServiceContainer` (SC).
#
# The SC is lazily initialized on fibers; this allows the SC to be accessed anywhere within the project.  The `Athena::DependencyInjection.container` method will return the SC for the current fiber.
# Since the SC is defined on fibers, it allows for each fiber to have its own SC instance.  This can be useful for web frameworks as each request would have its own SC scoped to that request.
#
# * See `ADI::Register` for documentation on registering services.
#
# NOTE: It is highly recommended to use interfaces as opposed to concrete types when defining the initializers for both services and non-services.
# Using interfaces allows changing the functionality of a type by just changing what service gets injected into it, such as via an alias.
# See this [blog post](https://dev.to/blacksmoke16/dependency-injection-in-crystal-2d66#plug-and-play) for an example of this.
module Athena::DependencyInjection
  private BINDINGS = {} of Nil => Nil

  # Allows binding a *value* to a *key* in order to enable auto registration of that value.
  #
  # Bindings allow scalar values, or those that could not otherwise be handled via [service aliases](./DependencyInjection/Register.html#aliasing-services), to be auto registered.
  # This allows those arguments to be defined once and reused, as opposed to using named arguments to manually specify them for each service.
  #
  # ```
  # module ValueInterface; end
  #
  # @[ADI::Register(_value: 1, name: "value_one")]
  # @[ADI::Register(_value: 2, name: "value_two")]
  # @[ADI::Register(_value: 3, name: "value_three")]
  # record ValueService, value : Int32 do
  #   include ValueInterface
  # end
  #
  # ADI.bind api_key, ENV["API_KEY"]
  # ADI.bind config, {id: 12_i64, active: true}
  # ADI.bind static_value, 123
  # ADI.bind odd_values, ["@value_one", "@value_three"]
  #
  # @[ADI::Register(public: true)]
  # record BindingClient,
  #   api_key : String,
  #   config : NamedTuple(id: Int64, active: Bool),
  #   static_value : Int32,
  #   odd_values : Array(ValueInterface)
  #
  # ADI.container.binding_client # =>
  # # BindingClient(
  # #  @api_key="123ABC",
  # #  @config={id: 12, active: true},
  # #  @static_value=123,
  # #  @odd_values=[ValueService(@value=1), ValueService(@value=3)])
  # ```
  macro bind(key, value)
    {% name = key.id.stringify %}

    {% BINDINGS[name] = value %}
  end

  # Registers a service based on the type the annotation is applied to.
  #
  # The type of the service affects how it behaves within the container.  When a `struct` service is retrieved or injected into a type, it will be a copy of the one in the SC (passed by value).
  # This means that changes made to it in one type, will _NOT_ be reflected in other types.  A `class` service on the other hand will be a reference to the one in the SC.  This allows it
  # to share state between services.
  #
  # ## Optional Arguments
  # In most cases, the annotation can be applied without additional arguments.  However, the annotation accepts a handful of optional arguments to fine tune how the service is registered.
  #
  # * `name : String`- The name of the service.  Should be unique.  Defaults to the type's FQN snake cased.
  # * `public : Bool` - If the service should be directly accessible from the container.  Defaults to `false`.
  # * `public_alias : Bool` - If a service should be directly accessible from the container via an alias.  Defaults to `false`.
  # * `lazy : Bool` - If the service should be lazily instantiated.  I.e. only instantiated when it is first accessed; either directly or as a dependency of another service.  Defaults to `true`.
  # * `alias : T` - Injects `self` when this type is used as a type restriction.  See the Aliasing Services example for more information.
  # * `tags : Array(String | NamedTuple(name: String, priority: Int32?))` - Tags that should be assigned to the service.  Defaults to an empty array.  See the Tagging Services example for more information.
  #
  # ## Examples
  #
  # ### Basic Usage
  # The simplest usage involves only applying the `ADI::Register` annotation to a type.  If the type does not have any arguments, then it is simply registered as a service as is.  If the type _does_ have arguments, then an attempt is made to register the service by automatically resolving dependencies based on type restrictions.
  #
  # ```
  # @[ADI::Register]
  # # Register a service without any dependencies.
  # struct ShoutTransformer
  #   def transform(value : String) : String
  #     value.upcase
  #   end
  # end
  #
  # @[ADI::Register(public: true)]
  # # The ShoutTransformer is injected based on the type restriction of the `transformer` argument.
  # struct SomeAPIClient
  #   def initialize(@transformer : ShoutTransformer); end
  #
  #   def send(message : String)
  #     message = @transformer.transform message
  #
  #     # ...
  #   end
  # end
  #
  # ADI.container.some_api_client.send "foo" # => FOO
  # ```
  #
  # ### Aliasing Services
  #
  # An important part of DI is building against interfaces as opposed to concrete types.  This allows a type to depend upon abstractions rather than a specific implementation of the interface.  Or in other works, prevents a singular implementation from being tightly coupled with another type.
  #
  # We can use the `alias` argument when registering a service to tell the container that it should inject this service when a type restriction for the aliased service is found.
  #
  # ```
  # # Define an interface for our services to use.
  # module TransformerInterface
  #   abstract def transform(value : String) : String
  # end
  #
  # @[ADI::Register(alias: TransformerInterface)]
  # # Alias the `TransformerInterface` to this service.
  # struct ShoutTransformer
  #   include TransformerInterface
  #
  #   def transform(value : String) : String
  #     value.upcase
  #   end
  # end
  #
  # @[ADI::Register]
  # # Define another transformer type.
  # struct ReverseTransformer
  #   include TransformerInterface
  #
  #   def transform(value : String) : String
  #     value.reverse
  #   end
  # end
  #
  # @[ADI::Register(public: true)]
  # # The `ShoutTransformer` is injected because the `TransformerInterface` is aliased to the `ShoutTransformer`.
  # struct SomeAPIClient
  #   def initialize(@transformer : TransformerInterface); end
  #
  #   def send(message : String)
  #     message = @transformer.transform message
  #
  #     # ...
  #   end
  # end
  #
  # ADI.container.some_api_client.send "foo" # => FOO
  # ```
  #
  # Any service that uses `TransformerInterface` as a dependency type restriction will get the `ShoutTransformer`.
  # However, it is also possible to use a specific implementation while still building against the interface.  The name of the constructor argument is used in part to resolve the dependency.
  #
  # ```
  # @[ADI::Register(public: true)]
  # # The `ReverseTransformer` is injected because the constructor argument's name matches the service name of `ReverseTransformer`.
  # struct SomeAPIClient
  #   def initialize(reverse_transformer : TransformerInterface)
  #     @transformer = reverse_transformer
  #   end
  #
  #   def send(message : String)
  #     message = @transformer.transform message
  #
  #     # ...
  #   end
  # end
  #
  # ADI.container.some_api_client.send "foo" # => oof
  # ```
  #
  # ### Scalar Arguments
  # The auto registration logic as shown in previous examples only works on service dependencies.  Scalar arguments, such as Arrays, Strings, NamedTuples, etc, must be defined manually.
  # This is achieved by using the argument's name prefixed with a `_` symbol as named arguments within the annotation.
  #
  # ```
  # @[ADI::Register(_shell: ENV["SHELL"], _config: {id: 12_i64, active: true}, public: true)]
  # struct ScalarClient
  #   def initialize(@shell : String, @config : NamedTuple(id: Int64, active: Bool)); end
  # end
  #
  # ADI.container.scalar_client # => ScalarClient(@config={id: 12, active: true}, @shell="/bin/bash")
  # ```
  # Arrays can also include references to services by prefixing the name of the service with an `@` symbol.
  #
  # ```
  # module Interface; end
  #
  # @[ADI::Register]
  # struct One
  #   include Interface
  # end
  #
  # @[ADI::Register]
  # struct Two
  #   include Interface
  # end
  #
  # @[ADI::Register]
  # struct Three
  #   include Interface
  # end
  #
  # @[ADI::Register(_services: ["@one", "@three"], public: true)]
  # struct ArrayClient
  #   def initialize(@services : Array(Interface)); end
  # end
  #
  # ADI.container.array_client # => ArrayClient(@services=[One(), Three()])
  # ```
  #
  # While scalar arguments cannot be auto registered by default, the `ADI.bind` macro can be used to support it.
  #
  # ### Tagging Services
  # Services can also be tagged.  Service tags allows another service to have all services with a specific tag injected as a dependency.
  # A tag consists of a name, and additional metadata related to the tag.
  # Currently the only supported metadata value is `priority`, which controls the order in which the services are injected; the higher the priority
  # the sooner in the array it would be.  In the future support for custom tag metadata will be implemented.
  #
  # ```
  # PARTNER_TAG = "partner"
  #
  # @[ADI::Register(_id: 1, name: "google", tags: [{name: PARTNER_TAG, priority: 5}])]
  # @[ADI::Register(_id: 2, name: "facebook", tags: [PARTNER_TAG])]
  # @[ADI::Register(_id: 3, name: "yahoo", tags: [{name: "partner", priority: 10}])]
  # @[ADI::Register(_id: 4, name: "microsoft", tags: [PARTNER_TAG])]
  # # Register multiple services based on the same type.  Each service must give define a unique name.
  # struct FeedPartner
  #   getter id
  #
  #   def initialize(@id : Int32); end
  # end
  #
  # @[ADI::Register(_services: "!partner", public: true)]
  # # Inject all services with the `"partner"` tag into `self`.
  # class PartnerClient
  #   def initialize(@services : Array(FeedPartner))
  #   end
  # end
  #
  # ADI.container.partner_client # =>
  # # #<PartnerClient:0x7f43c0a1ae60
  # #  @services=
  # #   [FeedPartner(@id=3, @name="Yahoo"),
  # #    FeedPartner(@id=1, @name="Google"),
  # #    FeedPartner(@id=2, @name="Facebook"),
  # #    FeedPartner(@id=4, @name="Microsoft")]>
  # ```
  #
  # ### Optional Services
  # Services defined with a nillable type restriction are considered to be optional.  If no service could be resolved from the type, then `nil` is injected instead.
  # Similarly, if the argument has a default value, that value would be used instead.
  #
  # ```
  # struct OptionalMissingService
  # end
  #
  # @[ADI::Register]
  # struct OptionalExistingService
  # end
  #
  # @[ADI::Register(public: true)]
  # class OptionalClient
  #   getter service_missing, service_existing, service_default
  #
  #   def initialize(
  #     @service_missing : OptionalMissingService?,
  #     @service_existing : OptionalExistingService?,
  #     @service_default : OptionalMissingService | Int32 | Nil = 12
  #   ); end
  # end
  #
  # ADI.container.optional_client
  # # #<OptionalClient:0x7fe7de7cdf40
  # #  @service_default=12,
  # #  @service_existing=OptionalExistingService(),
  # #  @service_missing=nil>
  # ```
  annotation Register; end

  # Specifies which constructor should be used for injection.
  #
  # ```
  # @[ADI::Register(_value: 2, public: true)]
  # class SomeService
  #   @active : Bool = false
  #
  #   def initialize(value : String, @active : Bool)
  #     @value = value.to_i
  #   end
  #
  #   @[ADI::Inject]
  #   def initialize(@value : Int32); end
  # end
  #
  # ADI.container.some_service # => #<SomeService:0x7f51a77b1eb0 @active=false, @value=2>
  # SomeService.new "1", true  # => #<SomeService:0x7f51a77b1e90 @active=true, @value=1>
  # ```
  #
  # Without the `ADI::Inject` annotation, the first initializer would be used, which would fail since we are not providing a value for the `active` argument.
  # `ADI::Inject` allows telling the service container that it should use the second constructor when registering this service.  This allows a constructor overload
  # specific to DI to be used while still allowing the type to be used outside of DI via other constructors.
  annotation Inject; end

  # Returns the `ADI::ServiceContainer` for the current fiber.
  def self.container : ADI::ServiceContainer
    Fiber.current.container
  end
end
