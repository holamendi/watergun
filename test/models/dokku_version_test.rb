require "test_helper"

class DokkuVersionTest < ActiveSupport::TestCase
  test "installer and local Docker pin the supported native storage release" do
    assert_match(/^DOKKU_TAG=v0\.38\.31$/, Rails.root.join("scripts/install.sh").read)
    assert_equal "dokku/dokku:0.38.31", YAML.load_file(Rails.root.join("docker-compose.yml")).dig("services", "dokku", "image")
  end
end
