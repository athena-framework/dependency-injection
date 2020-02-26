require "./spec_helper"

pending Athena::DependencyInjection do
  describe Athena::DependencyInjection::ServiceContainer do
    describe "compiler errors" do
      describe "when trying to access a private service directly" do
        it "should not compile" do
          assert_error "compiler/private_service.cr", "private method 'store' called for Athena::DependencyInjection::ServiceContainer"
        end
      end

      describe "when a service includes the module but is missing the annotation" do
        it "should not compile" do
          assert_error "compiler/missing_annotation.cr", "TheService includes `ADI::Service` but is not registered.  Did you forget the annotation?"
        end
      end

      describe "when a service has a non optional service dependency but it could not be resolved" do
        it "should not compile" do
          assert_error "compiler/missing_non_optional_service.cr", "Could not resolve dependency 'missing_service' for service 'Klass'.  Did you forget to include `ADI::Service` or declare it optional?"
        end
      end
    end
  end
end
