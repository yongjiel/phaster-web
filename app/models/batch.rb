class Batch < ActiveRecord::Base

  has_many :batch_submissions
  has_many :submissions, through: :batch_submissions

  SECRET_ID_LENGTH = 5

  before_validation :generate_batch_id, on: :create

  def to_param
    self.batch_id
  end

  def generate_batch_id
    self.batch_id = 'BB_' + SecureRandom.hex(SECRET_ID_LENGTH)
  end

  def zip_data_name
    "#{self.batch_id}.PHASTER.zip"
  end

  def zip_data(submissions)

    temp_file = Tempfile.new('temp')
    begin
      #Initialize the temp file as a zip file
      Zip::OutputStream.open(temp_file) { |zos| }

      Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip|

        submissions.each do |submission|

          # Include results in batch zip only if submission is complete
          if File.exist?(submission.summary_path) && File.exist?(submission.detail_path) && File.exist?(submission.phage_regions_path)
            zip.add(submission.job_id+"/"+'summary.txt', submission.summary_path)
            zip.add(submission.job_id+"/"+'detail.txt', submission.detail_path)
            zip.add(submission.job_id+"/"+'phage_regions.fna', submission.phage_regions_path)
          end
        end
      end

      #Read the binary data from the file
      zip_data = File.read(temp_file.path)
    ensure
      temp_file.close
      temp_file.unlink
    end
    zip_data
  end



end
