##################
# FIBER SPECIFIC #
##################
@[ADI::Register(public: true)]
class ValueStore
  property value : Int32 = 1
end

##############
# NAMESPACED #
##############
@[ADI::Register(public: true)]
class MyApp::Models::Foo
end

@[ADI::Register(public: true)]
class NamespaceClient
  getter service

  def initialize(@service : MyApp::Models::Foo); end
end

###############
# SINGLE TYPE #
###############
@[ADI::Register]
class SingleService
  getter value : Int32 = 1
end

@[ADI::Register(public: true)]
class SingleClient
  getter service : SingleService

  def initialize(@service : SingleService); end
end

#################
# MULTIPLE TYPE #
#################
module TransformerInterface
end

@[ADI::Register(alias: TransformerInterface)]
struct ReverseTransformer
  include TransformerInterface
end

@[ADI::Register]
struct ShoutTransformer
  include TransformerInterface
end

@[ADI::Register(public: true)]
class TransformerAliasClient
  getter service

  def initialize(transformer : TransformerInterface)
    @service = transformer
  end
end

@[ADI::Register(public: true)]
class TransformerAliasNameClient
  getter service

  def initialize(shout_transformer : TransformerInterface)
    @service = shout_transformer
  end
end

####################
# OPTIONAL SERVICE #
####################
struct OptionalMissingService
end

@[ADI::Register]
struct OptionalExistingService
end

@[ADI::Register(public: true)]
class OptionalClient
  getter service_missing, service_existing, service_default

  def initialize(
    @service_missing : OptionalMissingService?,
    @service_existing : OptionalExistingService?,
    @service_default : OptionalMissingService | Int32 | Nil = 12
  ); end
end

###################
# GENERIC SERVICE #
###################
@[ADI::Register(Int32, Bool, public: true, name: "int_service")]
@[ADI::Register(Float64, Bool, public: true, name: "float_service")]
struct GenericServiceBase(T, B)
  def type
    {T, B}
  end
end

##################
# SCALAR SERVICE #
##################
@[ADI::Register(_value: 22, _array: [1, 2, 3], _named_tuple: {id: 17_i64, active: true}, public: true)]
struct ScalarClient
  getter value, array, named_tuple

  def initialize(@value : Int32, @array : Array(Int32), @named_tuple : NamedTuple(id: Int64, active: Bool)); end
end

#################
# ARRAY SERVICE #
#################
module ArrayInterface
end

@[ADI::Register]
struct ArrayService
  include ArrayInterface
end

@[ADI::Register]
struct API::Models::NestedArrayService
  include ArrayInterface
end

@[ADI::Register(_services: ["@array_service", "@api_models_nested_array_service"], public: true)]
struct ArrayClient
  getter services

  def initialize(@services : Array(ArrayInterface?)); end
end

##################
# TAGGED SERVICE #
##################
private PARTNER_TAG = "partner"

@[ADI::Register(_id: 1, _name: "Google", name: "google", tags: [{name: PARTNER_TAG, priority: 5}])]
@[ADI::Register(_id: 2, _name: "Facebook", name: "facebook", tags: [PARTNER_TAG])]
@[ADI::Register(_id: 3, _name: "Yahoo", name: "yahoo", tags: [{name: "partner", priority: 10}])]
@[ADI::Register(_id: 4, _name: "Microsoft", name: "microsoft", tags: [PARTNER_TAG])]
struct FeedPartner
  getter id

  def initialize(@id : Int32, @name : String); end
end

@[ADI::Register(_services: "!partner", public: true)]
class PartnerClient
  getter services

  def initialize(@services : Array(FeedPartner))
  end
end
