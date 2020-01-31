require "../spec_helper"

@[ADI::Register]
class Store
  include ADI::Service

  property name : String = "Jim"
end

ADI::ServiceContainer.new.store
