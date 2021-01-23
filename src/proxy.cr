struct Athena::DependencyInjection::Proxy(O)
  forward_missing_to self.instance
  delegate :==, :===, :=~, :hash, :tap, :not_nil!, :dup, :clone, :try, to: self.instance

  getter instance : O { @loader.call }

  def initialize(@loader : Proc(O)); end
end
