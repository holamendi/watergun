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
gem "groupdate", github: "ankane/groupdate", branch: "master"
gem "honeybadger"
gem "httpx"
gem "jwt"
gem "lograge"
gem "mission_control-jobs"
gem "net-ssh"
gem "octokit"
gem "pagy", "~> 8.3"
gem "propshaft"
gem "puma", ">= 5.0"
gem "rack-mini-profiler"
gem "rails", "~> 8.1.0beta1"
gem "solid_cable"
gem "solid_queue", "~> 1.2.1"
gem "sqlite3", "~> 2.1.0"
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
  gem "minitest-spec-rails"
  gem "mocha"
  gem "selenium-webdriver"
  gem "vcr"
  gem "webmock"
end

group :development, :test do
  gem "debug", platforms: %i[mri windows]
  gem "standard"
end
