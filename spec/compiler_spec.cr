require "./spec_helper"

private TEST_CASES = {
  {
    "private_service",
    "private method 'service' called for Athena::DependencyInjection::ServiceContainer",
  },
  {
    "missing_non_optional_service",
    "Failed to resolve service '"missing_service"'.  Does it exist?",
  },
}

describe Athena::DependencyInjection do
  describe Athena::DependencyInjection::ServiceContainer do
    describe "compiler errors" do
      TEST_CASES.each do |(file_path, message)|
          it file_path do
            assert_error "compiler/#{file_path}.cr", message
          
        end
      end
    end
  end
end
