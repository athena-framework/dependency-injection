require "../spec_helper"

class MissingService
end

@[ADI::Register("@missing_service")]
class Klass
  def initialize(@service : MissingService); end
end

ADI::ServiceContainer.new
