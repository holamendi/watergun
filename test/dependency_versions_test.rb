require "minitest/autorun"
require "json"

class DependencyVersionsTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)

  def test_rails_uses_a_released_stable_gem_and_supported_migration_versions
    assert_match(/^gem "rails", "8\.1\.4"$/, File.read(File.join(ROOT, "Gemfile")))
    Dir[File.join(ROOT, "db/migrate/*.rb"), File.join(ROOT, "db/schema.rb")].each do |file|
      refute_match(/(?:Migration|Schema)\[8\.2\]/, File.read(file), file)
    end
  end

  def test_bundler_lock_uses_latest_stable
    assert_match(/BUNDLED WITH\n\s+4\.0\.22\n/, File.read(File.join(ROOT, "Gemfile.lock")))
  end

  def test_node_lts_builds_use_the_committed_lockfile
    docker = File.read(File.join(ROOT, "Dockerfile"))
    ci = File.read(File.join(ROOT, ".github/workflows/tests.yml"))
    assert_includes docker, "ARG NODE_VERSION=24.21.0"
    assert_includes ci, 'node-version: "24.21.0"'
    assert_equal 1, docker.scan("npm ci").size
    refute_match(/npm install|rm.*package-lock\.json/, docker)
    assert_includes ci, "npm ci"
    assert_includes File.read(File.join(ROOT, ".tool-versions")), "node 24.21.0"
  end

  def test_patch_and_minor_gems_are_current
    targets = {"bootsnap" => "1.26.0", "honeybadger" => "6.9.3", "http" => "6.0.4", "jwt" => "3.3.0", "lograge" => "0.15.1", "mission_control-jobs" => "1.3.1", "net-ssh" => "7.3.6", "puma" => "8.0.2", "pg" => "1.7.0", "store_attribute" => "2.2.0", "store_model" => "4.6.1", "vite_rails" => "3.11.1", "selenium-webdriver" => "4.51.0", "webmock" => "3.29.0", "standard" => "1.57.0"}
    lock = File.read(File.join(ROOT, "Gemfile.lock"))
    targets.each { |name, version| assert_match(/^    #{Regexp.escape(name)} \(#{Regexp.escape(version)}(?:\)|-)/, lock, name) }
  end

  def test_asset_dependencies_are_current_and_vite_ruby_is_compatible
    assert File.exist?(File.join(ROOT, "vite.config.mts")), "Vite's ESM config must have an unambiguous module extension"
    refute File.exist?(File.join(ROOT, "vite.config.ts"))
    targets = {"date-fns" => "4.4.0", "@tailwindcss/vite" => "4.3.3", "tailwindcss" => "4.3.3", "vite" => "8.3.4", "vite-plugin-ruby" => "5.2.5"}
    lock = JSON.parse(File.read(File.join(ROOT, "package-lock.json")))
    targets.each { |name, version| assert_equal version, lock.dig("packages", "node_modules/#{name}", "version"), name }
    package = JSON.parse(File.read(File.join(ROOT, "package.json")))
    assert_equal "^5.2.5", package.dig("devDependencies", "vite-plugin-ruby")
  end

  def test_latest_alba
    assert_match(/^    alba \(4\.0\.0\)/, File.read(File.join(ROOT, "Gemfile.lock")))
  end

  def test_latest_discard
    assert_match(/^    discard \(2\.0\.0\)/, File.read(File.join(ROOT, "Gemfile.lock")))
  end

  def test_latest_rack_mini_profiler
    assert_match(/^    rack-mini-profiler \(5\.0\.0\)/, File.read(File.join(ROOT, "Gemfile.lock")))
  end

  def test_latest_solid_cable
    assert_match(/^    solid_cable \(4\.1\.0\)/, File.read(File.join(ROOT, "Gemfile.lock")))
  end

  def test_latest_solid_queue_retains_threaded_workers
    assert_match(/^    solid_queue \(1\.7\.0\)/, File.read(File.join(ROOT, "Gemfile.lock")))
    queue = File.read(File.join(ROOT, "config/queue.yml"))
    assert_includes queue, "threads:"
    refute_includes queue, "fibers:"
    assert_includes File.read(File.join(ROOT, "config/application.rb")), "config.solid_queue.connects_to = nil"
  end

  def test_groupdate_uses_the_identical_released_source
    refute_includes File.read(File.join(ROOT, "Gemfile")), 'github: "ankane/groupdate"'
    refute_match(/^GIT$/, File.read(File.join(ROOT, "Gemfile.lock")))
    assert_match(/^    groupdate \(6\.8\.0\)/, File.read(File.join(ROOT, "Gemfile.lock")))
  end

  def test_latest_vite_plugin_rails
    lock = JSON.parse(File.read(File.join(ROOT, "package-lock.json")))
    assert_equal "0.6.0", lock.dig("packages", "node_modules/vite-plugin-rails", "version")
  end

  def test_latest_compatible_javascript_transitives
    targets = {"@rails/actioncable" => "8.1.400", "hotkeys-js" => "4.0.8", "obug" => "2.2.1", "vite-plugin-environment" => "1.1.4"}
    lock = JSON.parse(File.read(File.join(ROOT, "package-lock.json")))
    targets.each { |name, version| assert_equal version, lock.dig("packages", "node_modules/#{name}", "version"), name }
  end

  def test_latest_pagy
    assert_match(/^    pagy \(43\.7\.0\)/, File.read(File.join(ROOT, "Gemfile.lock")))
  end

  def test_compatible_transitive_dependencies_are_current
    targets = {"faraday" => "2.14.4", "faraday-net_http" => "3.4.4", "net-http" => "0.10.0", "ruby-lsp" => "0.26.11"}
    lock = File.read(File.join(ROOT, "Gemfile.lock"))
    targets.each { |name, version| assert_match(/^    #{Regexp.escape(name)} \(#{Regexp.escape(version)}\)/, lock, name) }
  end

  def test_ci_actions_are_reviewed_and_pinned
    ci = File.read(File.join(ROOT, ".github/workflows/tests.yml"))
    assert_includes ci, "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1"
    assert_includes ci, "actions/setup-node@949feb2413d6458794dcd2491c4babbbce0c15c1"
    assert_includes ci, "ruby/setup-ruby@e81a8fa391b11a595c1b7ed84177cc0fe02faf83"
    assert_includes ci, 'bundler: "4.0.22"'
    assert_includes File.read(File.join(ROOT, "Dockerfile")), "gem install bundler -v 4.0.22 --no-document"
  end

  def test_ruby_runtime_pins_are_latest_stable
    assert_equal "4.0.7", File.read(File.join(ROOT, ".ruby-version")).strip
    assert_includes File.read(File.join(ROOT, ".tool-versions")), "ruby 4.0.7"
    assert_includes File.read(File.join(ROOT, "Dockerfile")), "ARG RUBY_VERSION=4.0.7"
    assert_includes File.read(File.join(ROOT, ".github/workflows/tests.yml")), "ruby-version: 4.0.7"
  end
end
