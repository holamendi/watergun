class Api::V1::AppsController < Api::V1::ApplicationController
  after_action { response.headers.merge!(@pagy.headers_hash) if @pagy }

  def index
    @pagy, @apps = pagy(Current.account.apps.kept)
    render json: Api::V1::AppResource.new(@apps)
  end

  def show
    app = Current.account.apps.kept.find(params[:id])
    render json: Api::V1::AppResource.new(app)
  end
end
