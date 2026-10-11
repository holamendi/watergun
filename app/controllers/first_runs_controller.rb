class FirstRunsController < ApplicationController
  skip_before_action :authenticate
  before_action :set_user

  layout "sessions"

  def edit
  end

  def update
    completed = @user.with_lock do
      not_found! if @user.first_run_completed_at.present?
      @user.assign_attributes(user_params.merge(first_run_completed_at: Time.current))
      @user.save(context: :first_run)
    end

    if completed
      sign_in(@user)
      redirect_to root_path, notice: "Account created"
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_user
    @user = User.find_signed!(params[:signed_id], purpose: :first_run_v2)
    not_found! if @user.first_run_completed_at.present?
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    not_found!
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
