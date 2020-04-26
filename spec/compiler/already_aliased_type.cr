require "../spec_helper"

module AliasInterface
end

@[ADI::Register(alias: AliasInterface)]
struct One
  include AliasInterface
end

@[ADI::Register(alias: AliasInterface)]
struct Two
  include AliasInterface
end

ADI::ServiceContainer.new
