module Dokku
  module Plugin
    class Install < Base
      attr_reader :plugin, :repo

      PLUGIN_GITHUB_REPOS = {
        "clickhouse" => "dokku/dokku-clickhouse",
        "elasticsearch" => "dokku/dokku-elasticsearch",
        "letsencrypt" => "dokku/dokku-letsencrypt",
        "mariadb" => "dokku/dokku-mariadb",
        "meilisearch" => "dokku/dokku-meilisearch",
        "memcached" => "dokku/dokku-memcached",
        "mongo" => "dokku/dokku-mongo",
        "mysql" => "dokku/dokku-mysql",
        "postgres" => "dokku/dokku-postgres",
        "rabbitmq" => "dokku/dokku-rabbitmq",
        "redis" => "dokku/dokku-redis"
      }.freeze

      def initialize(ssh_session, plugin:)
        @ssh_session = ssh_session
        @plugin = plugin
        @repo = PLUGIN_GITHUB_REPOS.fetch(plugin)
      end

      def command
        "sudo dokku plugin:install https://github.com/#{repo}.git #{plugin}"
      end
    end
  end
end
