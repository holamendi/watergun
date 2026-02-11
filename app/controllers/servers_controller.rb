class ServersController < ApplicationController
  def select
    server = Current.account.servers.find(params[:id])
    cookies.signed.permanent[:server_id] = {value: server.id, http_only: true, same_site: :lax}
    redirect_to projects_path
  end
end
