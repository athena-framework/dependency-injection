require "./spec_helper"

private TEST_CASES = {
  {
    # More than one service of a given type exist, but ivar name doesn't match any, nor is an alias defined
    "cannot_auto_register_multiple_candidates",
    "Failed to auto register service 'klass'.  Could not resolve argument 'service : Interface'.",
  },
  {
    # Service could not be auto registered due to an argument not resolving to any services
    "cannot_auto_register_missing_service",
    "Failed to auto register service 'klass'.  Could not resolve argument 'service : MissingService'.",
  },
  {
    # An explicit argument references a service that hasn't been registered
    "cannot_register_explicit_argument",
    "Failed to register service 'missing_service'.  Could not resolve argument 'service : MissingService' from '@missing_service'.",
  },
  {
    # An explicit argument references a type that does not resolve to any services
    "cannot_register_explicit_argument_type",
    "Failed to register service 'klass'.  Could not resolve argument 'service : MissingService' from 'MissingService'.",
  },
  {
    # Service based on type that has multiple generic arguments does not provide the correct amount of generic arguments
    "generic_service_generics_count_mismatch",
    "Failed to register service 'generic_service'.  Expected 2 generics types got 1.",
  },
  {
    # Service based on generic type does provide any generic arguments
    "generic_service_generics_not_provided",
    "Failed to register service 'generic_service'.  Generic services must provide the types to use via the 'generics' field.",
  },
  {
    # Service based on generic type does not explicitly provide a name
    "generic_service_name_not_provided",
    "Failed to register service 'GenericService(T)'.  Generic services must explicitly provide a name.",
  },
  {
    # A named argument is an array more than 2 levels deep
    "nested_array_named_argument",
    "Failed to register service 'klass'.  Arrays more than two levels deep are not currently supported.",
  },
  {
    # Just assert services are not public by default
    "private_service",
    "private method 'service' called for Athena::DependencyInjection::ServiceContainer",
  },
  {
    # A name must be supplied if using a NamedTupleLiteral tag
    "tagged_service_invalid_tag_list_type",
    "Failed to register service `tagged_service`.  Tags must be an ArrayLiteral or TupleLiteral, not NumberLiteral.",
  },
  {
    # Tags can only be NamedTupleLiterals or StringLiterals
    "tagged_service_invalid_tag_type",
    "Failed to register service `tagged_service`.  A tag must be a StringLiteral or NamedTupleLiteral not BoolLiteral.",
  },
  {
    # A name must be supplied if using a NamedTupleLiteral tag
    "tagged_service_name_not_provided",
    "Failed to register service `tagged_service`.  All tags must have a name.",
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
