namespace :delete_test_submissions do
  task :detele_submissions => [:environment] do

    all_submissions = Submission.where('job_id like "ZZ%"')

    puts("To Delete:")
    puts(all_submissions.count)

    batches = Batch.all
    batch_submissions = BatchSubmission.all
    batch_submissions.each do |b|
      b.destroy!
    end
    batches.each do |b|
      b.destroy!
    end
    
    all_submissions.each do |submission|
      submission.destroy!
    end

  end
end
