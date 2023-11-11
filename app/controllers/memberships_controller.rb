class MembershipsController < ApplicationController
  before_action :set_membership, only: %i[ show edit update destroy ]

  # GET /memberships
  def index
    @memberships = Membership.all
  end

  # GET /memberships/1
  def show
  end

  # GET /memberships/new
  def new
    @membership = Membership.new
  end

  # GET /memberships/1/edit
  def edit
  end

  # POST /memberships
  def create
    @membership = Membership.new(membership_params)

    if @membership.save
      redirect_to @membership, notice: "Membership was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /memberships/1
  def update
    if @membership.update(membership_params)
      redirect_to @membership, notice: "Membership was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /memberships/1
  def destroy
    @membership.destroy!
    redirect_to memberships_url, notice: "Membership was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_membership
      @membership = Membership.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def membership_params
      params.require(:membership).permit(:user_id, :org_id)
    end
end
