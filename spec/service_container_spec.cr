require "./spec_helper"

describe Athena::DependencyInjection::ServiceContainer do
  describe "registration" do
    describe "that resolves to a single type" do
      it "should inject that type" do
        ADI.container.single_client.service.should be_a SingleService
      end
    end

    describe "that is namespaced" do
      it "correctly resolves the service" do
        ADI.container.namespace_client.service.should be_a MyApp::Models::Foo
      end
    end

    describe "that resolves to more than one type" do
      describe "with an alias" do
        it "should inject the aliased service based on interface" do
          ADI.container.transformer_alias_client.service.should be_a ReverseTransformer
        end

        it "allows overriding aliases" do
          ADI.container.get(ConverterInterface).should be_a ConverterTwo
        end
      end

      describe "variable name matches a service" do
        it "should inject the service whose ID matches the name of the constructor variable" do
          ADI.container.transformer_alias_name_client.service.should be_a ShoutTransformer
        end
      end
    end

    describe "where a dependency is optional" do
      describe "and does not exist" do
        describe "without a default value" do
          it "should inject `nil`" do
            ADI.container.optional_client.service_missing.should be_nil
          end
        end

        describe "with a default value" do
          it "should inject the default" do
            ADI.container.optional_client.service_default.should eq 12
          end
        end
      end

      describe "and does exist" do
        it "should inject that service" do
          ADI.container.optional_client.service_existing.should be_a OptionalExistingService
        end
      end
    end

    describe "with a generic service" do
      it "correctly initializes the service with the given generic arguments" do
        ADI.container.int_service.type.should eq({Int32, Bool})
        ADI.container.float_service.type.should eq({Float64, Bool})
      end
    end

    describe "with scalar arguments" do
      it "passes them to the constructor" do
        service = ADI.container.scalar_client
        service.value.should eq 22
        service.array.should eq [1, 2, 3]
        service.named_tuple.should eq({id: 17, active: true})
      end
    end

    describe "with explicit array of services" do
      it "passes them to the constructor" do
        services = ADI.container.array_client.services
        services[0].should be_a ArrayService
        services[1].should be_a API::Models::NestedArrayService
      end
    end

    describe "that is tag based" do
      it "injects all services with that tag, ordering based on priority" do
        services = ADI.container.partner_client.services
        services[0].id.should eq 3
        services[1].id.should eq 1
        services[2].id.should eq 2
        services[3].id.should eq 4
      end
    end

    describe "with bound values" do
      it "should use the bound values" do
        service = ADI.container.binding_client
        service.override_binding.should eq 2
        service.api_key.should eq "123ABC"
        service.config.should eq({id: 12_i64, active: true})
        service.odd_values.should eq [ValueService.new(1), ValueService.new(3)]
        service.prime_values.should eq [ValueService.new(2), ValueService.new(3)]
      end
    end
  end
end
