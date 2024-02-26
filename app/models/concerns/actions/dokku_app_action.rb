module Actions
  module DokkuAppAction
    extend ActiveSupport::Concern

    included do
      store_attribute :payload, :dokku_id, :string

      validates :dokku_id, presence: true
    end

    def create_dokku_app
      ssh.execute("dokku apps:create #{dokku_id}")
    end

    def dokku_app_urls
      ssh.execute("dokku urls #{dokku_id}").split("\n")
    end

    def destroy_dokku_app
      ssh.execute("dokku apps:destroy --force #{dokku_id}")
    end

    def restart_dokku_app
      ssh.execute("dokku ps:restart #{dokku_id}")
    end

    def rebuild_dokku_app
      ssh.execute("dokku ps:rebuild #{dokku_id}")
    end

    def enable_dokku_app_ssl
      ssh.execute("dokku letsencrypt:enable #{dokku_id}")
    end

    def dokku_app_ssl_enabled?
      ssh.execute("dokku letsencrypt:active #{dokku_id}").text_output.strip == "true"
    end
  end
end
