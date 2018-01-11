class BatchesController < ApplicationController
  before_action :set_batch, only: [:show]
    before_action :set_my_searches, only: [:show]

  # GET /batches
  # GET /batches.json
  def index
    @batches = Batch.all
  end

  # GET /batches/1
  # GET /batches/1.json
  def show

    batch_submissions = BatchSubmission.where(batch_id: @batch.id)
    @submissions = Array.new
    batch_submissions.each do |batch_sub|
      submission = Submission.find_by_id(batch_sub.submission_id)
      @submissions.push(submission)

    end

    respond_to do |format|
      format.zip { send_data(@batch.zip_data(@submissions), :type => 'application/zip', :filename => "#{@batch.zip_data_name}") }
      format.html do
        @remember_me = @my_searches.include?(@batch.batch_id)
       
      end
    end

  end

  # GET /batches/new
  def new
    @batch = Batch.new
  end

  # GET /batches/1/edit
  def edit
  end

  # POST /batches
  # POST /batches.json
  def create
    @batch = Batch.new(batch_params)

    respond_to do |format|
      if @batch.save
        format.html { redirect_to @batch, notice: 'Batch was successfully created.' }
        format.json { render :show, status: :created, location: @batch }
      else
        format.html { render :new }
        format.json { render json: @batch.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /batches/1
  # PATCH/PUT /batches/1.json
  def update
    respond_to do |format|
      if @batch.update(batch_params)
        format.html { redirect_to @batch, notice: 'Batch was successfully updated.' }
        format.json { render :show, status: :ok, location: @batch }
      else
        format.html { render :edit }
        format.json { render json: @batch.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /batches/1
  # DELETE /batches/1.json
  def destroy
    @batch.destroy
    respond_to do |format|
      format.html { redirect_to batches_url, notice: 'Batch was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_batch
      @batch = Batch.find_by_batch_id(params[:id])
    end

    def set_my_searches
      @my_searches = cookies[:my_searches].present? && JSON.parse(cookies[:my_searches]) || [ ]
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def batch_params
      params[:batch]
    end
end
