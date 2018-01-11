class SubmissionWorker
  include Sidekiq::Worker
  sidekiq_options :retry => false

  def perform(submission_id)
    start_time = Time.now
    submission = Submission.find(submission_id)
    submission.update!(status: 'running')

    if submission.category_identifier
      submission.logger('Downloading GenBank file from NCBI...')
      sequence = Bio::NCBI::REST::EFetch.nucleotide(submission.gi, "gbwithparts")
      if sequence.present?
        submission.sequence = StringIO.new(sequence)
        submission.sequence_file_name = 'genebank.gbk'
        submission.parse_ids_and_description
      else
        submission.error = "Could not download GenBank from NCBI."
      end
      submission.save!
    end

    flag = submission.genbank? ? '-g' : '-s'
    flag = '-c' if submission.contigs?

    cmd = "perl #{ENV['PHASTER_HOME']}/scripts/phaster.pl #{flag} #{submission.job_id}"
    submission.logger('Running phage script:')
    submission.logger(cmd)

    if Rails.env.production?
      pid = Process.spawn(cmd)
      begin
        Timeout.timeout(submission.allowed_runtime) do
          Process.wait(pid)
          if $?.exitstatus != 0
            submission.error =  "There was a problem running PHASTER. To help us resolve the problem, please <a href='/contact'>contact us</a> and provide the job id: #{submission.job_id}"
          end
        end
      rescue Timeout::Error
        Process.kill('TERM', pid)
        submission.error =  "The job timed out. Please try submitting your job again. If this happens again please <a href='/contact'>contact us</a> and provide the job id: #{submission.job_id}"
      end
    else
      example_dir = submission.contigs? ? "lib/example_results_contigs/*" : "lib/example_results/*"
      Dir.glob(example_dir).each do |src|
        if File.basename(src) == 'JOB_ID.log'
          log = File.read(src)
          submission.logger(log)
          next
        end
        dest = File.join( submission.job_dir, File.basename(src).sub('JOB_ID', submission.job_id) )
        FileUtils.cp(src, dest)
      end
    end

    if submission.error.present? || File.exist?(submission.fail_path)
      submission.status = "failed"
    elsif File.exist?(submission.success_path)
      submission.status = "complete"
      submission.phage_found = submission.parse_number_of_phage
    end

    # submission.runtime = Time.now - start_time
    # submission.save!

    if submission.contigs && submission.status == "complete"
      submission.parse_contigs
    end

  rescue StandardError => e
    submission.status = "failed"
    submission.error =  "There was a problem running PHASTER. To help us resolve the problem, please <a href='/contact'>contact us</a> and provide the job id: #{submission.job_id}"
    submission.logger(e.message)
    submission.logger(e.backtrace.join("\n"))
  ensure
    submission.runtime = Time.now - start_time
    submission.save!
  end

end