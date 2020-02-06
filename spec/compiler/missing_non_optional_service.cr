require "../spec_helper"

@[ADI::Register]
class MissingService
end

@[ADI::Register("@missing_service")]
class Klass
  include ADI::Service

  def initialize(@service : MissingService); end
end

ADI::ServiceContainer.new
