struct Athena::DependencyInjection::Proxy(O)
  forward_missing_to self.instance
  delegate :==, :===, :=~, :hash, :tap, :not_nil!, :dup, :clone, :try, to: self.instance

  getter instance : O { @loader.call }

  getter service_id : String

  def initialize(@service_id : String, @loader : Proc(O)); end

  def service_type : O.class
    O
  end
end
