class Api::V1::AppsController < Api::V1::ApplicationController
  after_action { pagy_headers_merge(@pagy) if @pagy }

  def index
    @pagy, @apps = pagy(Current.account.apps.kept)
    render json: AppResource.new(@apps)
  end

  def show
    app = Current.account.apps.kept.find(params[:id])
    render json: AppResource.new(app)
  end
end
