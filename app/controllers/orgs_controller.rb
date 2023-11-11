class OrgsController < ApplicationController
  before_action :set_org, only: %i[ show edit update destroy ]

  # GET /orgs
  def index
    @orgs = Org.all
  end

  # GET /orgs/1
  def show
  end

  # GET /orgs/new
  def new
    @org = Org.new
  end

  # GET /orgs/1/edit
  def edit
  end

  # POST /orgs
  def create
    @org = Org.new(org_params)

    if @org.save
      redirect_to @org, notice: "Org was successfully created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /orgs/1
  def update
    if @org.update(org_params)
      redirect_to @org, notice: "Org was successfully updated.", status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /orgs/1
  def destroy
    @org.destroy!
    redirect_to orgs_url, notice: "Org was successfully destroyed.", status: :see_other
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_org
      @org = Org.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def org_params
      params.require(:org).permit(:name)
    end
end
