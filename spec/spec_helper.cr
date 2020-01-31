require "spec"
require "../src/athena-dependency_injection"

CONTAINER = ADI::ServiceContainer.new

# Asserts compile time errors given a *path* to a program and a *message*.
def assert_error(path : String, message : String) : Nil
  buffer = IO::Memory.new
  result = Process.run("crystal", ["run", "--no-color", "--no-codegen", "spec/" + path], error: buffer)
  fail buffer.to_s if result.success?
  buffer.to_s.should contain message
  buffer.close
end

# Runs the the binary with the given *name* and *args*.
def run_binary(name : String = "bin/athena", args : Array(String) = [] of String, &block : String -> Nil)
  buffer = IO::Memory.new
  Process.run(name, args, error: buffer, output: buffer)
  yield buffer.to_s
  buffer.close
end
