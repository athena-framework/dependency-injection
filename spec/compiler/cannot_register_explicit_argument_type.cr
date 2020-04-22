require "../spec_helper"

class MissingService
end

@[ADI::Register(_service: MissingService)]
class Klass
  def initialize(@service : MissingService); end
end

ADI::ServiceContainer.new
