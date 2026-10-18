class Api::V1::EnvController < Api::V1::ApplicationController
  api_scope "env:write", only: :update
  wrap_parameters false

  def update
    body = mutation_body
    return if performed?
    raise ServerAction::Accept::Error, "invalid_request" unless body.keys.sort == %w[mode values]
    accept_operation(App.new(id: params[:id]), endpoint: "PUT /api/v1/apps/:id/env", scope: "env:write", body: body) do |app|
      usable_app!(app)
      command = EnvVariable::WriteEnvVariables.new(app: app, mode: body["mode"], values: body["values"])
      raise ServerAction::Accept::Error, "validation_failed" unless command.save(enqueue: false)
      command.server_action_run
    end
  end

  private

  def process_action(*)
    # Do not let ParamsWrapper/instrumentation parse a secret-bearing body.
    # Rails logs raw malformed JSON before filtering it. mutation_body alone
    # reads and validates the bounded body, without exposing parser causes.
    request.request_parameters = {}
    super
  end
end
