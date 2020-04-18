require "../spec_helper"

@[ADI::Register(name: "generic_service", generics: [Int32])]
class GenericService(A, B)
  def initialize(@value : B); end
end

ADI::ServiceContainer.new
