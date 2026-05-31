class DokkuImportsController < ApplicationController
  IMPORT_PROJECT_NAME = "Dokku Import"

  def create
    if running_import_action
      redirect_to server_action_path(running_import_action), notice: "Dokku import is already running"
      return
    end

    import_project = find_or_create_import_project
    import_action = ServerActions::ImportDokkuProject.create!(
      server: Current.server,
      actionable: import_project,
      include_watergun: include_watergun?
    )
    import_action.run_later

    redirect_to server_action_path(import_action), notice: "Dokku import started"
  end

  private

  def running_import_action
    @running_import_action ||= Current.server.actions
      .queued_or_running
      .where(type: ServerActions::ImportDokkuProject.name)
      .recent
      .first
  end

  def find_or_create_import_project
    Current.server.projects.kept.dokku_imports.first || Current.account.projects.create!(
      server: Current.server,
      name: import_project_name,
      dokku_import: true
    )
  end

  def import_project_name
    base_name = IMPORT_PROJECT_NAME
    name = base_name
    suffix = 2

    while Current.account.projects.kept.exists?(name:)
      name = "#{base_name} #{suffix}"
      suffix += 1
    end

    name
  end

  def include_watergun?
    ActiveModel::Type::Boolean.new.cast(params[:include_watergun]) || false
  end
end
