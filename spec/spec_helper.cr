require "spec"
require "../src/athena-dependency_injection"
require "./service_mocks"

require "athena-spec"
require "../src/spec"

include ASPEC::Methods

record DBConfig, username : String, password : String, host : String

class ACF::Parameters
  getter db : DBConfig

  def initialize(@db : DBConfig); end
end

def ACF.load_parameters : ACF::Parameters
  ACF::Parameters.new DBConfig.new "USER", "PASS", "HOST"
end
