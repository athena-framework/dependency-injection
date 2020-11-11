# A set of testing utilities/types to aid in testing `Athena::DependencyInjection` related types.
#
# ### Getting Started
#
# Require this module in your `spec_helper.cr` file.
#
# ```
# # This also requires "spec".
# require "athena-dependency_injection/spec"
# ```
module Athena::DependencyInjection::Spec
  # A mock implementation of `ADI::ServiceContainer` that be used within a testing context to allow for mocking out services without affecting the actual container outside of tests.
  #
  # An example of this is when integration testing service based [ART::Controller](https://athena-framework.github.io/athena/Athena/Routing/Controller.html)s.
  # Service dependencies that interact with an external source, like a third party API or a database, should most likely be mocked out.
  # However your other services should be left as is in order to get the most benefit from the test.
  #
  # The `ADI::ServiceContainer` is nothing more than a normal Crystal class with some instance variables and methods.
  # As such, mocking services is as easy as monkey patching `self` with the mocked versions, assuming of course they are of a compatible type.
  #
  # ### Dynamic Mocks
  #
  # A dynamic mock consists of adding a `setter` to `self` that allows setting the mocked service dynamically at runtime,
  # while keeping the original up until if/when it is replaced.
  #
  # ```
  # class ADI::Spec::MockableServiceContainer
  #   # The setter should be nilable as they're lazily initialized within the container.
  #   setter my_service : MyServiceInterface?
  # end
  #
  # # ...
  #
  # # Now the `my_service` service can be replaced at runtime.
  # mock_container.my_service = MockMyService.new
  #
  # # ...
  # ```
  #
  # ### Global Mocks
  #
  # Global mocks totally replace the original service, i.e. always return the mocked service.
  #
  # ```
  # class ADI::Spec::MockableServiceContainer
  #   # Global mocks should use the block based `getter` macro.
  #   getter my_service : MyServiceInterface { MockMyService.new }
  # end
  #
  # # `MockMyService` will now be injected across the board when using `self`.
  #
  # # ...
  # ```
  #
  # ### Hybrid Mocks
  #
  # Dynamic and Global mocking can also be combined to allow having a default mock, but allow overriding if/when needed.
  # This can be accomplished by adding both a getter and setter to `self.`
  #
  # ```
  # class ADI::Spec::MockableServiceContainer
  #   # Hybrid mocks should use the block based `property` macro.
  #   property my_service : MyServiceInterface { DefaultMockService.new }
  # end
  #
  # # ...
  #
  # # `DefaultMockService` will now be injected across the board by when using `self`.
  #
  # # But can still be replaced at runtime.
  # mock_container.my_service = CustomMockService.new
  #
  # # ...
  # ```
  #
  # NOTE: Services that need to be mockable should be based on interfaces and use `type` argument as part of the `ADI::Register` annotation.
  # This allows that service to be replaced (either dynamically or globally) with another type that implements that interface.
  class MockableServiceContainer < ADI::ServiceContainer; end
end
