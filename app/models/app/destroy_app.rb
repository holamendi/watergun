class App::DestroyApp
  def initialize(app)
    @app = app
  end

  def destroy(enqueue: true)
    run = ServerAction::Enqueue.build(action: "apps.destroy", target: @app)
    enqueue ? ServerAction::Enqueue.persist(run) : run
  end
end
