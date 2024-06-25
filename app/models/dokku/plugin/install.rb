module Dokku
  module Plugin
    class Install < Base
      attr_reader :plugin, :repo

      PLUGIN_GITHUB_REPOS = {
        "clickhouse" => "https://github.com/dokku/dokku-clickhouse.git",
        "elasticsearch" => "https://github.com/dokku/dokku-elasticsearch.git",
        "letsencrypt" => "https://github.com/dokku/dokku-letsencrypt.git",
        "mariadb" => "https://github.com/dokku/dokku-mariadb.git",
        "meilisearch" => "https://github.com/dokku/dokku-meilisearch.git",
        "memcached" => "https://github.com/dokku/dokku-memcached.git",
        "mongo" => "https://github.com/dokku/dokku-mongo.git",
        "mysql" => "https://github.com/dokku/dokku-mysql.git",
        "postgres" => "https://github.com/dokku/dokku-postgres.git",
        "rabbitmq" => "https://github.com/dokku/dokku-rabbitmq.git",
        "redis" => "https://github.com/dokku/dokku-redis.git"
      }.freeze

      def initialize(ssh_session, plugin:)
        @ssh_session = ssh_session
        @plugin = plugin
        @repo = PLUGIN_REPOS.fetch(plugin)
      end

      def command
        "sudo dokku plugin:install #{repo} #{plugin}"
      end
    end
  end
end
