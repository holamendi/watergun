source "https://rubygems.org"

ruby file: ".ruby-version"

gem "alba"
gem "bcrypt", "~> 3.1.7"
gem "bootsnap", require: false
gem "bytesize"
gem "chartkick"
gem "discard"
gem "dotenv"
gem "ed25519"
gem "faraday-retry"
gem "groupdate", "6.8.0"
gem "honeybadger"
gem "http"
gem "jwt"
gem "lograge"
gem "mission_control-jobs"
gem "net-ssh"
gem "octokit"
gem "pagy", "~> 43.7"
gem "propshaft"
gem "puma", ">= 5.0"
gem "rack-mini-profiler"
gem "rails", "8.1.4"
gem "solid_cable"
gem "solid_queue", "~> 1.7.0"
gem "pg", "~> 1.5"
gem "sshkey"
gem "store_attribute"
gem "store_model"
gem "turbo-rails"
gem "tzinfo-data", platforms: %i[windows jruby]
gem "vite_rails"

group :development do
  gem "web-console"
  gem "ruby-lsp-rails"
end

group :test do
  gem "archspec", "~> 1.1.0", require: false
  gem "json_schemer", "~> 2.5"
  gem "minitest-spec-rails"
  gem "mocha"
  gem "prism", ">= 1.0", require: false
  gem "selenium-webdriver"
  gem "vcr"
  gem "webmock"
end

group :development, :test do
  gem "debug", platforms: %i[mri windows]
  gem "standard"
end
