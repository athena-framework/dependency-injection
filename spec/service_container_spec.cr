require "./spec_helper"

describe ADI::ServiceContainer do
  describe "#get" do
    describe "by type" do
      it "should return an array of services with that type" do
        services = CONTAINER.get FakeServices
        services.size.should eq 2
        services[0].should be_a FakeService
        services[1].should be_a CustomFooFakeService
      end
    end

    describe "by name" do
      it "should allow getting public services directly" do
        CONTAINER.store.name.should eq "Jim"
      end
    end

    describe "with array/namedTuple arguments" do
      it "should be injected correctly" do
        service = CONTAINER.static_args
        service.scalar_arr.should eq [1, 2, 3]
        service.service_arr.first.should be_a CustomFooFakeService
        service.named_tuple_arg.should eq({id: 99, active: true})
      end
    end

    it "should use the overridden service" do
      CONTAINER.error_renderer.value.should eq 2
    end
  end

  describe "#has?" do
    describe "when the service has been registered" do
      it "should return true" do
        CONTAINER.has?("blah").should be_true
      end
    end

    describe "when the service has been registered" do
      it "should return false" do
        CONTAINER.has?("i_do_not_exist").should be_false
      end
    end
  end

  describe "#resolve" do
    describe "when there are no services with the type" do
      it "should raise an exception" do
        expect_raises Exception, "Could not resolve a service with type 'UnknownService' and name of 'unknown_service'." { CONTAINER.resolve UnknownService, "unknown_service" }
      end
    end

    describe "when there is a single match" do
      it "should return the service" do
        CONTAINER.resolve(FakeService, "fake_service").should be_a FakeService
      end
    end

    describe "when there is are multiple matches" do
      describe "that does not match the name" do
        it "should raise an exception" do
          expect_raises Exception, "Could not resolve a service with type 'FeedPartner' and name of 'yahoo'." { CONTAINER.resolve FeedPartner, "yahoo" }
        end
      end

      describe "when the name and type are not related" do
        it "should raise an exception" do
          expect_raises Exception, "Could not resolve a service with type 'FakeServices' and name of 'google'." { CONTAINER.resolve FakeServices, "google" }
        end
      end

      describe "that matches a name" do
        it "should return the service" do
          service = CONTAINER.resolve(FeedPartner, "google").as(FeedPartner)
          service.should be_a FeedPartner
          service.id.should eq "GOOGLE"
        end
      end
    end
  end

  describe "#tagged" do
    it "should return the service with the given tag" do
      services = CONTAINER.tagged("partner")
      services.size.should eq 2

      google = services[0].as(FeedPartner)
      google.should be_a FeedPartner
      google.id.should eq "GOOGLE"

      facebook = services[1].as(FeedPartner)
      facebook.should be_a FeedPartner
      facebook.id.should eq "FACEBOOK"
    end

    it "should return the service with the given tag" do
      services = CONTAINER.tagged("feed_partner")
      services.size.should eq 1

      google = services[0].as(FeedPartner)
      google.should be_a FeedPartner
      google.id.should eq "GOOGLE"
    end

    it "should return the service with the given tag" do
      CONTAINER.tagged("fake_tag").should eq [] of ADI::Service
    end
  end

  describe "optional" do
    describe "that is not registered" do
      it "should supply nil" do
        CONTAINER.optional_missing.service.should be_nil
      end
    end

    describe "that is registered" do
      it "should supply the service" do
        CONTAINER.optional_registered.logger.should be_a Logger
      end
    end
  end
end
