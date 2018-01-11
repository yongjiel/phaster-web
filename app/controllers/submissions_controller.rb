class SubmissionsController < ApplicationController
  before_action :set_submission, only: [:show, :edit, :update, :destroy, :status]
  before_action :set_my_searches, only: [:my_searches, :show, :create, :status]
  before_action :set_batch, only: [:show, :status]
  # before_action :set_batch_submissions, only: :create

  # GET /submissions
  # GET /submissions.json
  def index
    @submissions = Submission.where(category: 'identifier').where(status: 'complete')
  end

  def my_searches
    @submissions = Submission.where(job_id: @my_searches)
    @batches = Batch.where(batch_id: @my_searches)
  end

  # GET /submissions/1
  # GET /submissions/1.json
  def show

    if @submission.finalized?
      respond_to do |format|
        format.zip { send_data(@submission.zip_data, :type => 'application/zip', :filename => "#{@submission.zip_data_name}") }
        format.html do
          @remember_me = @my_searches.include?(@submission.job_id)
          # A lot of file reading happens here so let's just do a catch-all rescue
          # statement for now in case there are reading/parsing errors
          # Should probably fix this later to actually identify any errors during parsing
          begin

            @summary = @submission.parse_summary
          rescue => e
            @summary_error = "Error parsing summary results file for display."
            # puts e.message
            # puts e.backtrace
          end

          begin
            @details = @submission.parse_details
          rescue => e
            @details_error = "Error parsing details results file for display."
            # puts e.message
            # puts e.backtrace
          end

          begin
            @chart = @submission.parse_chart
          rescue => e
            @chart_error = "Error parsing image data file for display. "
            # puts e.message
            # puts e.backtrace
          end
        end
      end
    else

      redirect_to status_submission_path(@submission, batch_id: @batch ? @batch.batch_id : nil)
    end
  end

  # GET /submissions/new
  def new
    @submission = Submission.new
    @remember_search = cookies[:remember_search].present? ? cookies[:remember_search] : true
    @get_cache = true
    # To remember which tab is selected
    @selected_tab ||= "file"
  end

  # GET /submissions/1/edit
  def edit
  end

  # POST /submissions
  # POST /submissions.json
  def create

    params[:contigs] = ['true', true, 1, '1'].include?(params[:contigs]) ? true : false
    params[:get_cache] = ['true', true, 1, '1'].include?(params[:get_cache]) ? true : false
    params[:remember_search] = ['true', true, 1, '1'].include?(params[:remember_search]) ? true : false

    multi_fasta = false
    multi_gbk = false
    @input_contents = ""
    @get_cache = params[:get_cache]
    
    # Hack to temporarily disable use of cache.
    params[:get_cache] = false
    @get_cache = false

    if submission_params[:sequence] && params[:contigs]==false
      @selected_tab = "file"
      @input_contents = submission_params[:sequence].read
    elsif params[:sequence_text]
      @selected_tab = "text"
      @input_contents = params[:sequence_text]
    end

    if !@input_contents.empty?
      @input_contents.gsub!("\r\n", "\n")
      @input_contents.gsub!("\r", "\n")
      if @input_contents[0]==">" && @input_contents.lines.reject{|s| s[0]!=">"}.count > 1
        multi_fasta = true
      elsif @input_contents.lines.first.include?("LOCUS") && @input_contents.scan("//\n").count>1
        multi_gbk = true
      end
    end

    if multi_fasta || multi_gbk

      respond_to do |format|

        # Check whether cluster is in good working order.
        if (msg = check_cluster) != ''
          @submission = Submission.new # dummy submission whose only purpose is to render an error message
          @submission.errors[:base] << msg
          format.html { render action: 'new' } # renders error message
          format.js
          return
        end

        batch_submissions, batch_success = parse_batch_submissions(params[:get_cache], multi_fasta, multi_gbk)

        if !batch_success

          #Display the header for the sequence that failed
          @submission.parse_ids_and_description

          @remember_search = params[:remember_search].present?
          format.html { render action: 'new' }
          format.js

          batch_submissions.each do |job_id|
            submission = Submission.find_by_job_id(job_id)
            submission.destroy!
          end

        else

          @batch = Batch.new
          @batch.save!
          batch_submissions.each do |job_id|
            submission = Submission.find_by_job_id(job_id)
            if submission.status != "complete"
              submission.queue_phaster
            end
            batch_submission = BatchSubmission.new
            batch_submission.batch_id = @batch.id
            batch_submission.submission_id = submission.id
            batch_submission.save!
          end
          @batch.update!(seq_count: batch_submissions.count)

          if params[:remember_search]
            cookies.permanent[:remember_search] = '1'
            if @batch.batch_id.present?
              cookies.permanent[:my_searches] = JSON.generate( @my_searches.push(@batch.batch_id).uniq )
            end
          else
            cookies.delete :remember_search
          end

          format.html { redirect_to @batch }
          format.js

        end 

      end


    else #NOT multi-fasta - do as before
      @submission = Submission.new(submission_params)
      @submission.status = 'validating'

      # Account for jquery form weirdness

      # If the form has been submitted via jquery-fileupload, i.e. a 
      # sequence file as input, then we sent create.js
      respond_to do |format|

        @submission.contigs = params[:contigs]

        if @submission.category_identifier
          @selected_tab = "identifier"
          @submission.gi_and_accession_from_identifier(params[:identifier])
          if found_submission = Submission.where(gi: @submission.gi, category: 'identifier').first
            if found_submission.failed?
              found_submission.destroy
              found_submission = nil
            else
              @submission = found_submission
              format.html { redirect_to found_submission }
              format.js
            end
          end
        elsif @submission.category_text
          @selected_tab = "text"
          @submission.add_sequence_from_text(params[:sequence_text])
          @submission.replace_newline_characters

          found_submission = get_found_submission(params[:get_cache])
          if !@submission.sequence_length.nil? && !found_submission.nil?
            @submission = found_submission
            format.html { redirect_to found_submission }
            format.js
          end
        else
          @selected_tab = "file"
          @submission.replace_newline_characters

          found_submission = get_found_submission(params[:get_cache])
          if !@submission.sequence_length.nil? && !found_submission.nil?
            @submission = found_submission
            format.html { redirect_to found_submission }
            format.js
          end
        end

        unless found_submission

          @submission.generate_contig_fileid if @submission.contigs
          @submission.concatenate_contigs if @submission.contigs
          
          # Check whether cluster is in good working order.
          if (msg = check_cluster) != ''
            @submission.errors[:base] << msg
            format.html { render action: 'new' } # renders error message
            format.js
            return
          end

          if @submission.save
            @submission.queue_phaster
            format.html { redirect_to status_submission_path(@submission) }
            format.js
          else
            if @submission.contigs
              @submission.delete_contig_files
            end

            @remember_search = params[:remember_search].present?
            format.html { render action: 'new' }
            format.js
          end
        end
      end

      if params[:remember_search]
        cookies.permanent[:remember_search] = '1'
        if @submission.job_id.present?
          cookies.permanent[:my_searches] = JSON.generate( @my_searches.push(@submission.job_id).uniq )
        end
      else
        cookies.delete :remember_search
      end
  
    end #END IF (multi-fasta/not)
  end


  def status
    @remember_me = @my_searches.include?(@submission.job_id)
    if @submission.finalized?
      respond_to do |format|
        format.html { redirect_to submission_path(@submission, batch_id: @batch ? @batch.batch_id : nil)  }
        format.js { render js: "window.location.reload(true)" }
      end
    end
  end

  # PATCH/PUT /submissions/1
  # PATCH/PUT /submissions/1.json
  def update
    respond_to do |format|
      if @submission.update(submission_params)
        format.html { redirect_to @submission, notice: 'Submission was successfully updated.' }
        format.json { render :show, status: :ok, location: @submission }
      else
        format.html { render :edit }
        format.json { render json: @submission.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /submissions/1
  # DELETE /submissions/1.json
  def destroy
    @submission.destroy
    respond_to do |format|
      format.html { redirect_to submissions_url, notice: 'Submission was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  # For downloading images
  def download
    uri = URI::Data.new(params[:data])
    send_data uri.data, :filename => "#{params[:filename]}.png", :type => "image/png"
  end
  
  # Used when site is down for maintenance and we show an alternate homepage
  def maintenance
  end

  private

    # Use callbacks to share common setup or constraints between actions.
    def set_submission
      @submission = Submission.find_by_job_id(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def submission_params
      params.require(:submission).permit(:sequence, :category)
    end

    def set_my_searches
      @my_searches = cookies[:my_searches].present? && JSON.parse(cookies[:my_searches]) || [ ]
    end


    def set_batch
      @batch = Batch.find_by_batch_id(params[:batch_id])
    end

    #maximum number of sequences in batch is 10
    def parse_batch_submissions(get_cache, multi_fasta, multi_gbk)
      full_sequence = ""
      sequence_count = 0
      batch_success = true

      batch_submissions = Array.new
      line_count = @input_contents.lines.count

      if multi_fasta
        new_char = ">"
      elsif multi_gbk
        new_char = "//\n"
      end

      @input_contents.split("\n"+new_char).each do |sequence|
        break if sequence_count >= 10
        next if sequence.empty?

        if multi_fasta && sequence[0]!=">"
          sequence = new_char + sequence
        elsif multi_gbk
          sequence += "\n"+new_char
        end

        @submission = Submission.new(submission_params)
        @submission.sequence = StringIO.new(sequence)
        @submission.status = 'validating'
        @submission.replace_newline_characters

        found_submission = get_found_submission(get_cache)
        if !@submission.sequence_length.nil? && !found_submission.nil?
          @submission = found_submission
          batch_submissions.push(@submission.job_id)

        else
          if @submission.save
            batch_submissions.push(@submission.job_id)
          else
            batch_success = false
            break
          end
        end

        sequence_count += 1
      end
       
      return batch_submissions, batch_success
    end

    def get_found_submission(get_cache)
      @submission.check_sequence
      @submission.parse_sequence_length
      @submission.count_nucleotides_from_upload

      if @submission.sequence_length.nil?
        found_submission = nil
      elsif !get_cache
        found_submission = nil
      else
        # puts 'DEBUG:>>>'
        if found_submission = Submission.where(sequence_length: @submission.sequence_length, adenine_count: @submission.adenine_count,
          guanine_count: @submission.guanine_count, cytosine_count: @submission.cytosine_count, thymine_count: @submission.thymine_count, contigs: @submission.contigs).first
          # if found_submission = check_validity_of_sequence(found_submission, @submission)

            if found_submission.failed?
              begin
                #Will not delete if part of a batch
                found_submission.destroy
              rescue
              end
              found_submission = nil
            end

            if found_submission
              if found_submission.status != "complete"
                found_submission = nil
              end
            end
          # end
        else
          found_submission = nil
        end
      end

      return found_submission

    end

    def check_validity_of_sequence(submissions, submission_temp)
      submissions.each do |s|
        if File.exist?(s.sequence.path)
          file = File.read(s.sequence.path)
        else
          next
        end

        c_file = File.read(submission_temp.sequence.queued_for_write[:original].path)

        if c_file.to_s == file.to_s
          return s
        end
      end
      return nil
    end    

    # Checks whether botha1 cluster is accessible and in good working order.
    # If everything is fine, returns the empty string.
    # If there is a problem, returns an error message.
    def check_cluster
      hostname = "botha1.cs.ualberta.ca"
      username = "prion"
      keys = ['/apps/phaster/.ssh/botha', '~/.ssh/id_rsa'] # private keys to test (not all the files need to exist)

      # Can we connect?
      begin
        ssh = Net::SSH.start(hostname, username, :keys => keys, :auth_methods => ['publickey']) # Only try public key authentication.
      rescue
        #puts "Unable to connect to #{hostname} using #{username}"
        return('Unable to connect to the computing cluster! Please contact PHASTER support so the issue can be addressed.')
      end

      # Can qsub command be found?
      res = ssh.exec!('which qsub')
      if res =~ /no qsub in/
        return('A problem was detected on the computing cluster! Please contact PHASTER support so the issue can be addressed.')
      end

      # Are there any cluster child nodes that are alive?
      res = ssh.exec!('alive')
      c = 0
      res.split("\n").each { |line|
        c += 1
      }
      #puts "#{c} child nodes available"
      if c == 0
        return('A problem was detected on the computing cluster! Please contact PHASTER support so the issue can be addressed.')
      end

      ssh.close
      return('')
    end

end
