class PhasterApiController < ApplicationController

  skip_before_filter  :verify_authenticity_token

  def show

    identifier = acc_params[:acc]

    @submission = Submission.new(category: 'identifier')
    @submission.status = 'validating'

    if identifier =~ /ZZ_/
      if found_submission = Submission.where(job_id: identifier).first
        @submission = found_submission
        respond_to_request(@submission, @submission.status)
      else

        render json: {job_id: identifier, error: "Submission with this job id does not exist."}
      end
    else

      @submission.gi_and_accession_from_identifier(identifier)
      if found_submission = Submission.where(gi: @submission.gi, accession: @submission.accession, category: 'identifier').first

        @submission = found_submission
        respond_to_request(@submission, @submission.status)
          
      end
    
      unless found_submission

        begin
          @submission.save!
        rescue
          respond_to_request(@submission, @submission.status)
          return
        end

        @submission.queue_phaster("low")
        respond_to_request(@submission, @submission.status)

      end
    end

  end

  def post_file

    file = file_from_params
    
    begin
      content = File.read(file)
    rescue
      render json: {job_id: nil, error: "Sequence file is empty or not specified. Please check!"}
      return
    end

    contigs = params[:contigs]
    begin
      contigs = contigs.to_i
    rescue
    end



    @submission = Submission.new
    @submission.category = "text"
    @submission.status = "validating"
    @submission.add_sequence_from_text(content)
    @submission.replace_newline_characters

    @submission.contigs = contigs if contigs == 1
    @submission.generate_contig_fileid if @submission.contigs
    @submission.concatenate_contigs if @submission.contigs


    @submission.check_sequence
    @submission.parse_sequence_length
    @submission.count_nucleotides_from_upload

    begin
      @submission.save!
    rescue

      if @submission.contigs
        @submission.delete_contig_files
      end

      respond_to_request(@submission, @submission.status)
      return

    end

    @submission.queue_phaster("low")
    
    respond_to_request(@submission, @submission.status)

  end

  # Alternate version when not accepting new API submissions:
  def post_file_maintenance
    render json: {job_id: nil, error: "PHASTER is currently undergoing maintenance. Please try again later."}
  end

  def respond_to_request(submission, status)

    if status == "complete"
      url_site = "phaster.ca/submissions/"+submission.job_id
      url_zip = url_site+".zip"

      render json: {job_id: submission.job_id, status: submission.display_status("low"), url: url_site, zip: url_zip, summary: File.read("#{Rails.root}/public/jobs/" +  submission.job_id + "/summary.txt")}
    elsif status=="failed" || status=="validating"
      fail_message = ""

      if status=="failed"
        if File.exist?(submission.fail_path)
          fail_message = File.read(submission.fail_path)
        end
      end

      if fail_message.empty?
        if submission.error
          fail_message = submission.error.gsub("<a href='/contact'>contact us</a>", "contact us")
        elsif submission.errors
          fail_message = submission.errors.full_messages.uniq.join("\n")
        end
      end

      if fail_message.empty?
        fail_message = "Your submission failed to run. Please try again!"
      end

      render json: {job_id: submission.job_id, error: fail_message}
    else

      render json: {job_id: submission.job_id, status: submission.display_status("low")}
    end
  end 

  def acc_params
    params.permit(:acc)
  end

  def file_params
    params.permit(:'post-file', :contigs)
  end

  def file_from_params
    file = request.body.read
    return nil if file.blank?
    temp = Tempfile.new(['import', '.fna'])
    temp.write file
    temp.rewind
    temp
  end



end
