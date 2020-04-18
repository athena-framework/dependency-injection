require "spec"
require "../src/athena-dependency_injection"

CONTAINER = ADI::ServiceContainer.new

# Asserts compile time errors given a *path* to a program and a *message*.
def assert_error(path : String, message : String) : Nil
  buffer = IO::Memory.new
  result = Process.run("crystal", ["run", "--no-color", "--no-codegen", "spec/#{path}"], error: buffer)
  fail buffer.to_s if result.success?
  buffer.to_s.should contain message
  buffer.close
end
