class FirstRunsController < ApplicationController
  skip_before_action :authenticate
  before_action :set_user

  layout "sessions"

  def edit
  end

  def update
    completed = @user.with_lock do
      not_found! unless User.where(id: @user.id).find_by_token_for(:first_run, params[:signed_id])
      @user.assign_attributes(user_params)
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
    @user = User.find_by_token_for!(:first_run, params[:signed_id])
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    not_found!
  end

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end
end
