require "./spec_helper"

private TEST_CASES = {
  {
    "private_service",
    "private method 'service' called for Athena::DependencyInjection::ServiceContainer",
  },
  {
    # The provided service does not exist
    "missing_non_optional_service",
    "Failed to resolve service 'missing_service'.  Does it exist?",
  },
  {
    # No services with the given type restriction are registered
    "cannot_resolve_missing_service",
    "Could not auto resolve argument 'service : MissingService'.  Does it exist?",
  },
  {
    # A named argument points to a service that doesn't exist
    "cannot_resolve_named_argument",
    "Failed to resolve service 'missing_service'.  Does it exist?",
  },
  {
    # More than one service of a given type exist, but ivar name doesn't match any, nor is an alias defined
    "cannot_resolve_service_from_multiple",
    "Could not auto resolve argument 'service : Interface'.",
  },
  {
    # Service based on generic type does not explicitly provide a name
    "generic_service_name_not_provided",
    "Services based on the generic type 'GenericService(T)' must explicitly provide a name.",
  },
  {
    # Service based on generic type does provide any generic arguments
    "generic_service_generics_not_provided",
    "Service 'generic_service' must provide the generic vars it should use via the 'generics' field.",
  },
  {
    # Service based on type that has multiple generic arguments does not provide the correct amount of generic arguments
    "generic_service_generics_count_mismatch",
    "Wrong number of generic arguments provided for 'generic_service'.  Expected 2 got 1.",
  },
  {
    # Tags can only be NamedTupleLiterals or StringLiterals
    "tagged_service_invalid_tag_type",
    "Tags for service `tagged_service` must be a StringLiteral or NamedTupleLiteral not BoolLiteral.",
  },
  {
    # A name must be supplied if using a NamedTupleLiteral tag
    "tagged_service_name_not_provided",
    "Tags for service `tagged_service` must must have a name.",
  },
  {
    # A name must be supplied if using a NamedTupleLiteral tag
    "tagged_service_invalid_tag_list_type",
    "Tags for service `tagged_service` must be an ArrayLiteral or TupleLiteral, not NumberLiteral.",
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
