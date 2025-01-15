ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

VCR.configure do |config|
  config.cassette_library_dir = "test/vcr_cassettes"
  config.hook_into :webmock
  config.allow_http_connections_when_no_cassette = true
  config.filter_sensitive_data("<ACCESS_TOKEN>") do |interaction|
    interaction.request.headers["Authorization"].first.split(" ").last
  end
end

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    include SessionTestHelper

    def json_response
      ::JSON.parse(response.body)
    end
  end
end
