class JobsController < ApplicationController
  before_action :set_job, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show, :new]
  after_action :create_user_job, only: [:create]
  before_action :registered_user?, only: [:new]
  before_action :profile_complete?, only: [:new]
  before_action :is_trader?, only: [:accept]


  # GET /jobs
  # GET /jobs.json
  def index
    # Search function
    if params[:job] && params[:job][:category_id].present? && params[:postcode].present?
      category_search = JobCategory.find(params[:job][:category_id])
      postcode_search = params[:postcode]
      search_result = Job.where("postcode = ? AND job_category_id = ?", postcode_search, category_search.id)
      @jobs = select_available_jobs(search_result)

      @message = "Search result for: #{category_search.category} in #{postcode_search}"
    elsif params[:job] && params[:job][:category_id].present?
      category_search = JobCategory.find(params[:job][:category_id])
      job_category_search = JobCategory.where(category: category_search.category)
      job_category_search = job_category_search.first
      search_result = job_category_search.jobs
      @jobs = select_available_jobs(search_result)

      @message = "Search result for: #{category_search.category}"
    elsif params[:postcode].present?
      postcode_search = params[:postcode]
      job_postcode_search = Job.where(postcode: postcode_search)
      @jobs = select_available_jobs(job_postcode_search)

      @message = "Search Result for Postcode: #{postcode_search}"
    else
      @jobs = select_available_jobs(Job.all)
    end 
  end

  # GET /jobs/1
  # GET /jobs/1.json 
  def show
    # To decide whether the current user is the job creator or acceptor. The first user will always be the creator and the second user acceptor
    @is_job_creator = current_user == @job.users.first
    if @job.users.count > 1
      @is_job_acceptor = current_user == @job.users.second
    end
    @job_status = @job.job_status_id
    # Define the message shown at different statuses to different users.
    # Statuses: 1 -> created, 2 -> accepted, 3 -> completed, 4 -> paid
    if @job_status == 1 && @is_job_creator
        @message = "Congratulations! Your job is successfully created! We will send you an email when someone takes the job!"
    elsif @job_status == 1
      @message = "This job is available. Click ACCEPT to take the job"
    elsif @job_status == 2 && @is_job_creator
      @message = "This job has been taken. We will send you an email when the job is completed"
    elsif @job_status == 2 && @is_job_acceptor
      @message = "You have accepted this job, click COMPLETE after you've finished the job"
    elsif @job_status == 3 && @is_job_acceptor
      @message = "Waiting for payment. We will send you an email when the payment is received"
    elsif @job_status == 3 && @is_job_creator
      @message = "The tradie has finished this job. Please make the payment"
    elsif @job_status == 4
      @message = "The job has been paid. Thank you for choosing TradeUp"
    end

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
    # assigns user(tradesman) to job in the join table
    @user_job = UserJob.new 
    @user_job.user_id = current_user.id
    @user_job.job_id = params[:id].to_i
    @user_job.save

    @job = Job.find(params[:id])
    # sets the job status to 'accepted'
    @job.job_status_id = 2
    @job.save
    redirect_to @job
    JobMailer.with(user: @job.users.first).job_taken_email.deliver_now
  end

  # GET /jobs/1/completed
  def complete
    @job = Job.find(params[:id])
    # sets the job status to 'completed'
    @job.job_status_id = 3
    @job.save
    redirect_to @job
    JobMailer.with(user: @job.users.first).payment_reminder_email.deliver_now
  end

  # GET /jobs/1/paid
  def pay
    @job = Job.find(params[:id])
    # sets the job status to 'paid'
    @job.job_status_id = 4
    @job.save
    redirect_to @job
    JobMailer.with(user: @job.users.second).payment_received_email.deliver_now 
  end

  # POST /jobs
  # POST /jobs.json
  def create
    @job = Job.new(job_params)
    # sets the job status to 'created'
    @job.job_status_id = 1
    respond_to do |format|
      if @job.save
        format.html { redirect_to @job }
        format.json { render :show, status: :created, location: @job }
      else
        format.html { render :new }
        format.json { render json: @job.errors, status: :unprocessable_entity }
      end
    end
    JobMailer.with(user: current_user).job_posted_email.deliver_now 
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
      result = params.require(:job).permit(:title, :description, :tenant_available_time, :job_category_id, :price, :street_number, :street_name, :city, :postcode, :state, :job_status_id, :tenant_one_name, :tenant_two_name, :tenant_one_contact, :tenant_two_contact, images: [])
      result[:price] = result[:price].to_f * 100
      result
    end

    # creates the user _job entry when a job is creates
    def create_user_job
      puts "creating user jobs"
      @user_job = UserJob.new 
      @user_job.user = current_user
      @user_job.job = Job.last
      @user_job.save
    end

    def is_trader?
      user_profile = current_user.user_profile
      if !user_profile.abn.present? || !user_profile.insurance.present?
        redirect_to edit_user_profile_path(user_profile.id, :abn_insurance => 0, :job_id => params[:job_id])
      end
    end

    def profile_complete?
      user_profile = current_user.user_profile
      if !user_profile.name.present? || !user_profile.contact.present? || !user_profile.street_number.present? || !user_profile.business_name.present?
        if params[:job] && params[:job][:category_id]
          redirect_to edit_user_profile_path(user_profile.id, :job_category => params[:job][:category_id])
        elsif params[:job_category]
          redirect_to edit_user_profile_path(user_profile.id, :job_category => params[:job_category])
        else
          redirect_to edit_user_profile_path(user_profile.id, :job_new => 0)
        end
      end
    end

    def registered_user?
      if !current_user
        redirect_to new_user_registration_path(:job_category => params[:job][:category_id])
      end
    end

    # Method to select the jobs that are not accepted yet. Created but not accepted jobs have one user; Accepted jobs have two users.
    def select_available_jobs(array)
      jobs = []
      array.each do |job|
        if job.users.count <2
          jobs << job
        end
      end
      return jobs
    end
end

