require "./spec_helper"

describe ADI::Injectable do
  describe "with only services" do
    it "should inject an instance of the Store class" do
      klass = SomeClass.new
      klass.store.should be_a Store
      klass.store.name.should eq "Jim"
    end
  end

  describe "with a non service argument" do
    it "should auto inject the store" do
      klass = OtherClass.new id: "FOO"
      klass.id.should eq "FOO"
      klass.store.should be_a Store
      klass.store.name.should eq "Jim"
    end
  end

  describe "when overriding the service" do
    it "should use the mocked service" do
      klass = OtherClass.new id: "FOO", store: FakeStore.new
      klass.id.should eq "FOO"
      klass.store.should be_a FakeStore
      klass.store.name.should eq "TEST"
    end
  end

  describe "with other required services" do
    it "should inject an instance of the Store class" do
      klass = FooBar.new
      klass.serv.blah.should be_a Blah
      klass.serv.foo.should eq "a_string"
      klass.serv.ase.should be_a AService
    end
  end

  describe "when injecting tagged services" do
    it "should inject all services with that tag" do
      klass = PartnerParamConverter.new
      klass.manager.partners.size.should eq 2

      klass.manager.partners[0].id.should eq "GOOGLE"
      klass.manager.partners[1].id.should eq "FACEBOOK"
    end
  end
end
