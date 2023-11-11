require "rails_helper"

RSpec.describe OrgsController, type: :routing do
  describe "routing" do
    it "routes to #index" do
      expect(get: "/orgs").to route_to("orgs#index")
    end

    it "routes to #new" do
      expect(get: "/orgs/new").to route_to("orgs#new")
    end

    it "routes to #show" do
      expect(get: "/orgs/1").to route_to("orgs#show", id: "1")
    end

    it "routes to #edit" do
      expect(get: "/orgs/1/edit").to route_to("orgs#edit", id: "1")
    end


    it "routes to #create" do
      expect(post: "/orgs").to route_to("orgs#create")
    end

    it "routes to #update via PUT" do
      expect(put: "/orgs/1").to route_to("orgs#update", id: "1")
    end

    it "routes to #update via PATCH" do
      expect(patch: "/orgs/1").to route_to("orgs#update", id: "1")
    end

    it "routes to #destroy" do
      expect(delete: "/orgs/1").to route_to("orgs#destroy", id: "1")
    end
  end
end
