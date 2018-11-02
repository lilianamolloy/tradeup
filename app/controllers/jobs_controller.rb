class JobsController < ApplicationController
  before_action :set_job, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show]
  after_action :create_user_job, only: [:create]
  before_action :accept_job, only: [:accept]

  # GET /jobs
  # GET /jobs.json
  def index
    # jobs that haven't been accepted, so jobs with only one user will be displayed, jobs with two users won't display
    @jobs = []
    Job.all.each do |job|
      if job.users.count < 2
        @jobs << job
      end
    end
    
    if params[:query].present?
      job_category_search = JobCategory.where("category LIKE ?", '%crescent%').all
      job_category_search = job_category_search.first
      @jobs = job_category_search.jobs
      
    else 
      @jobs
    end 
  end

  # GET /jobs/1
  # GET /jobs/1.json
  def show
  end

  # GET /jobs/new
  def new
    @job = Job.new
  end

  # GET /jobs/1/edit
  def edit
    authorize @job
  end

  # GET /jobs/1/accept
  def accept
    @job = Job.find(params[:id])
  end

  # POST /jobs
  # POST /jobs.json
  def create
    @job = Job.new(job_params)

    respond_to do |format|
      if @job.save
        format.html { redirect_to @job, notice: 'Job was successfully created.' }
        format.json { render :show, status: :created, location: @job }
      else
        format.html { render :new }
        format.json { render json: @job.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /jobs/1
  # PATCH/PUT /jobs/1.json
  def update
    respond_to do |format|
      if @job.update(job_params)
        format.html { redirect_to @job, notice: 'Job was successfully updated.' }
        format.json { render :show, status: :ok, location: @job }
      else
        format.html { render :edit }
        format.json { render json: @job.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /jobs/1
  # DELETE /jobs/1.json
  def destroy
    authorize @job
    @job.destroy
    respond_to do |format|
      format.html { redirect_to jobs_url, notice: 'Job was successfully deleted.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_job
      @job = Job.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def job_params
      params.require(:job).permit(:title, :description, :tenant_available_time, :job_category_id, :price, :image, :street_number, :street_name, :city, :postcode, :state)
    end

    # creates the user _job entry when a job is creates
    def create_user_job
      @user_job = UserJob.new 
      @user_job.user_id = current_user.id
      @user_job.job_id = Job.last.id
      @user_job.save
    end

    def accept_job
      @user_job = UserJob.new 
      @user_job.user_id = current_user.id
      @user_job.job_id = params[:id].to_i
      @user_job.save
    end
  end
