class FirstRunsController < ApplicationController
  skip_before_action :authenticate!
  before_action :set_user

  layout "sessions"

  def edit
  end

  def update
    if @user.update(user_params)
      sign_in(@user)
      redirect_to root_path, notice: "Account created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def set_user
    @user = User.find_signed!(params[:signed_id], purpose: :first_run)
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    not_found!
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
