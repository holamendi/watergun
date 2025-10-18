module Dokku
  module Plugin
    class InstallCommand
      PLUGINS = {
        clickhouse: "dokku/dokku-clickhouse.git",
        elasticsearch: "dokku/dokku-elasticsearch.git",
        letsencrypt: "dokku/dokku-letsencrypt.git",
        mariadb: "dokku/dokku-mariadb.git",
        meilisearch: "dokku/dokku-meilisearch.git",
        memcached: "dokku/dokku-memcached.git",
        mongo: "dokku/dokku-mongo.git",
        mysql: "dokku/dokku-mysql.git",
        postgres: "dokku/dokku-postgres.git",
        rabbitmq: "dokku/dokku-rabbitmq.git",
        redis: "dokku/dokku-redis.git"
      }.freeze

      def initialize(plugin:)
        @plugin = plugin
        @repo = PLUGINS.fetch(plugin.to_sym)
      end

      def cmd
        "sudo dokku plugin:install https://github.com/#{@repo} #{@plugin}"
      end
    end
  end
end
