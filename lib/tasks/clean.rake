require 'csv'
include Net::SSH
include Net::SFTP

namespace :clean do
  
  # Delete unneeded intermediate files within job directories to save disk space.
  task :delete_unneeded_files => [:environment] do
    matched_submissions = Submission.where('updated_at < DATE_SUB(NOW(), INTERVAL 30 DAY)')
    
    puts("To clean:")
    puts(matched_submissions.count)
    
    matched_submissions.each do |submission|
      delete_if_exists(submission.predicted_genes_path)
      delete_if_exists(submission.predicted_genes_ptt_path)
      delete_if_exists(submission.predicted_gene_aa_seqs_path)
      delete_if_exists(submission.tRNAscan_output_path)
      delete_if_exists(submission.tmRNA_aragorn_path)
      delete_if_exists(submission.extracted_tRNA_tmRNA_path)
      delete_if_exists(submission.blast_results_against_phage_db_path)
      delete_if_exists(submission.genes_not_matched_to_phage_path)
      delete_if_exists(submission.blast_results_against_bacterial_db_path)
      delete_if_exists(submission.temporary_summary_path)
      delete_if_exists(submission.accession_dir_path_1)
      delete_if_exists(submission.accession_dir_path_2)

      #puts submission.accession_dir_path
    end
    
  end
  
  def delete_if_exists(path)
    FileUtils.rm_rf(path) if File.exist?(path)
  end
  
  task :delete_old_contig_submissions => [:environment] do
    matched_submissions = Submission.where('job_id like "ZZ%" and contigs = 1 and updated_at < DATE_SUB(NOW(), INTERVAL 30 DAY)')
    
    puts("To delete:")
    puts(matched_submissions.count)
    
    matched_submissions.each do |submission|
      submission.destroy!
    end
  end
  
  # Delete a portion of old user submissions.
  # Note: This should only be used in emergencies, as normally we want to retain all user
  # submissions.
  task :delete_submissions => [:environment] do
    num_user_submissions = Submission.where('job_id like "ZZ%"').count
    num_delete = num_user_submissions/10
    
    # We exclude user submissions that are part of batch submissions
    to_delete = Submission.where('job_id like "ZZ%" and id not in (?)',
        BatchSubmission.select(:submission_id).map(&:submission_id)).order(:updated_at).limit(num_delete)
    
    puts "Deleting #{to_delete.count} oldest user submissions..."
    to_delete.each do |submission|
      puts 'DELETE: ' + submission.job_id.to_s + ' ' + submission.updated_at.to_s
      submission.destroy!
    end
  end
  
  # Delete submissions from on or after the given date.
  task :delete_submissions_after_date => [:environment] do
    time_range = (Date.parse('2016-11-25'))..Time.now
    to_delete = Submission.where("created_at" => time_range)
    to_delete.each do |submission|
      puts 'DELETE: ' + submission.job_id.to_s + ' ' + submission.updated_at.to_s
      submission.destroy!
    end
  end
  
  # Delete submissions based on the input list of job ids.
  task :delete_submissions_list => [:environment] do
    CSV.open("to_purge.txt", "r", :col_sep => "\t").each do |row|
      job_id = row[0]
      submission = Submission.where(job_id: job_id).first
      if submission.nil?
        puts job_id + ' does not exist'
      else
        puts 'DELETE: ' + submission.job_id.to_s + ' ' + submission.updated_at.to_s
        submission.destroy!
      end
    end
  end
  
  # Delete job directories on the cluster if they have been deleted on the front-end.
  #
  # WARNING: Be sure to either run this on the production server, or make sure you have
  # synced your local copy of the phaster database within the past 24 hours (or whatever
  # threshold is given below for mtime_threshold).
  #
  task :delete_dirs_on_cluster => [:environment] do
    cluster_server = 'botha1.cs.ualberta.ca'
    cluster_user = 'prion'
    cluster_access_keys = ["/apps/phaster/.ssh/botha", "/Users/darndt/.ssh/scp-key"]
    cluster_jobs_dir = '/home/prion/phaster-app/JOBS/'
    mtime_threshold = 24*60*60*30 # 30 day, in seconds
    
    to_keep = Submission.where('job_id like "ZZ_%"')
    to_keep_hash = {}
    to_keep.each do |submission|
      to_keep_hash[submission.job_id] = 1
    end
    
    Net::SSH.start(cluster_server, cluster_user, :keys => cluster_access_keys) do |ssh|
      
      current_time_sec = Time.new.to_i
      
      trim_len = cluster_jobs_dir.length + 3 # add 3 for the 2-letter nesting directory
      
      on_cluster_abbrev = ssh.exec!("ls -d #{cluster_jobs_dir}*")
      on_cluster_abbrev = on_cluster_abbrev.split("\n")
      
      on_cluster_abbrev.map! { |abbrev_path|
        abbrev = abbrev_path[-2..-1]
        abbrev_dir = abbrev + '/'
        
        on_cluster = ssh.exec!("ls  #{cluster_jobs_dir}#{abbrev_dir} | grep ZZ_")
        on_cluster = on_cluster.split("\n")
        
        on_cluster.map! { |path|
          job_id = path.gsub(".tz", '')
          if !to_keep_hash.key?(job_id)
            # job id is on cluster but is not a job on the front-end
          
            # Check the directory modification time on the server. We do not want to delete
            # a brand new directory on the server if it was created just after we grabbed
            # the list of all jobs from the front-end.
            #Net::SFTP.start(cluster_server, cluster_user, :keys => cluster_access_keys) do |sftp|
            begin
              ssh.sftp.connect do |sftp|
                mtime_sec = sftp.stat!("#{cluster_jobs_dir}#{abbrev_dir}#{path}").mtime # in seconds since the epoch
                if current_time_sec - mtime_sec > mtime_threshold
                  # Directory is older than the threshold, so we can delete it if it's missing
                  # on the front-end.
              
                  command = "rm -rf #{cluster_jobs_dir}#{abbrev_dir}#{path} "
                  puts("Remove #{cluster_jobs_dir}#{abbrev_dir}#{path} in botha1 cluster!")
                  response = ssh.exec!(command)
                end
              end
            rescue Net::SFTP::StatusException => e
              # Ignore -- happens when there are no jobs starting with ZZ_ within a nesting directory.
              
#               $stderr.puts "ERROR: Net::SFTP::StatusException with #{cluster_jobs_dir}#{abbrev_dir}#{job_id}"
#               $stderr.puts e.response
            end
          else
            #puts("#{job_id} is in web side.")
          end
        }
        
      }
      
    end
  end


  desc "sync Mysql DB and cluster if there is any job ids deleted in file system first."\
       " This task will run long time. So use nohup. After the task starts, it has to run"\
       " to the end instead of stop by sending a signal. Or cluster part maybe not synced."
  task :sync_db_cluster => [:environment] do
    all_submissions = Submission.all()
    submission_dirs = []
    batch_ids = []
    all_related_submissions = []
    all_submissions.each do |submission|
      if !File.exist?(submission.job_dir)
        submission_dirs.push(submission.job_dir) 
        batch_submission = BatchSubmission.find_by(submission_id: submission.id)
        if !batch_submission.nil? and !batch_ids.include?(batch_submission.batch_id)
          batch_ids.push(batch_submission.batch_id)
          all_related_submissions.push(BatchSubmission.find_by(batch_id: batch_submission.batch_id).submission_id)
        end
      end
    end
    all_related_submissions = all_related_submissions.flatten
    all_related_submissions.map! do |submission_id|
        submission = Submission.where(id: submission_id).first()
        submission.job_dir
    end
    puts("submission will be deleted. Before merge: #{submission_dirs.length}")
    submission_dirs += all_related_submissions
    puts("submission will be deleted. After merge : #{submission_dirs.length}")
    submission_dirs = submission_dirs.uniq
    puts("submission will be deleted. after merge and uniq : #{submission_dirs.length}")
    job_ids = []
    submission_dirs.each do |s_d|
      j_id = File.basename(s_d)
      j_id.gsub(/\s/, "\\ ")
      job_ids.push(j_id)
    end
    sync_db(job_ids)
    sync_cluster(job_ids)
    puts("Task is done!")
  end

  def sync_db(job_ids)
    job_ids.each do |j|
      subm = Submission.where(:job_id => j).first()
      if ! subm.nil?
        subm.destroy!
        puts("#{j} deleted from DB")
      end
    end
  end

  def sync_cluster(job_ids)
    cluster_server = 'botha1.cs.ualberta.ca'
    cluster_user = 'prion'
    cluster_access_keys = ["/apps/phaster/.ssh/botha", "/Users/darndt/.ssh/scp-key"]
    cluster_jobs_dir = '/home/prion/phaster-app/JOBS'
    Net::SSH.start(cluster_server, cluster_user, :keys => cluster_access_keys) do |ssh|
      job_ids.each do |j|
        if j.match("ZZ_")
          dir = j[3..4]
        else
          dir = j[0..1]
        end
        ssh.exec!("ls  #{cluster_jobs_dir}/#{dir}/#{j}*") do |ch, stream, data|
          if stream == :stderr
            puts "ERROR: No #{cluster_jobs_dir}/#{dir}/#{j}* in cluster"
          else
            # job_id exists
            ssh.exec!("rm -rf #{cluster_jobs_dir}/#{dir}/#{j}*")
            puts("#{cluster_jobs_dir}/#{dir}/#{j} deleted in CLUSTER")
          end
        end
      end
    end
  end 

end
