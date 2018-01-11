namespace :generate do

  desc "Generate md5 hash for sequences and save them to submissions"
  task md5_hash: [:environment] do
    Submission.where('sequence_length is not null and sequence_hash is null').each do |s|
      # now obsolete
      # s.generate_md5_hash
      # s.save!
    end
  end

  desc "Generate adenine, guanine, cytosine and thymine counts"
  task nucleotide_counts: [:environment] do
    Submission.where('sequence_length is not null and adenine_count is null').each do |s|
      s.count_nucleotides
      s.save!
    end
  end
end