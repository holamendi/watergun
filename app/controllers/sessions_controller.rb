class SessionsController < ApplicationController
  skip_before_action :authenticate_session!
  before_action :set_session, only: %i[show edit update destroy]

  # GET /sessions
  def index
    @sessions = Session.all
  end

  # GET /sessions/1
  def show
  end

  # GET /sessions/new
  def new
    redirect_to root_path if cookies.encrypted[:session_token].present?

    @session = Session.new
  end

  # GET /sessions/1/edit
  def edit
  end

  # POST /sessions
  def create
    @user = User.authenticate_by(session_params)

    if @user
      Current.session = @user.sessions.create!
      cookies.encrypted[:session_token] = {value: Current.session.token, expires: Current.session.expires_at}
      redirect_to root_path
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /sessions/1
  def update
    if @session.update(session_params)
      redirect_to @session, notice: "Session was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /sessions/1
  def destroy
    @session.destroy!
    redirect_to sessions_url, notice: "Session was successfully destroyed.", status: :see_other
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_session
    @session = Session.find(params[:id])
  end

  # Only allow a list of trusted parameters through.
  def session_params
    params.require(:session).permit(:email, :password)
  end
end
