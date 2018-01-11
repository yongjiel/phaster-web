namespace :fail_current_jobs do
  task :change_status => [:environment] do
    jobs = Submission.where(status: "running")
    jobs.each do |job|
      job.status = "failed"
      job.save!
    end
  end
end
