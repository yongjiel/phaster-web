JOBS_DIR = "../../../phaster-app/JOBS/"

namespace :import do

  desc "Import old phaster results into database"
  task old_results: [:environment] do
    Dir.foreach(JOBS_DIR) do |entry|
      if File.directory?(JOBS_DIR + entry) && File.file?(JOBS_DIR + entry + "/" + entry + ".gbk")
        gbk = File.open(JOBS_DIR + entry + "/" + entry + ".gbk", 'r')
	
	      puts entry
        next if Submission.exists?(job_id: entry)
        submission = Submission.new
        submission.accession = entry
        submission.job_id = entry
        submission.category = "identifier"
        submission.sequence_type = "genbank"
        submission.sequence_file_name = entry + ".gbk"
        submission.sequence_content_type = "text/plain"
        submission.sequence_file_size = File.size(JOBS_DIR + entry + "/" + entry + ".gbk")

        if File.file?(JOBS_DIR + entry + "/" + entry + ".done")
          submission.status = "complete"
        else
          submission.status = "failed"
        end

        gbk.readlines.each do |line|
          if /^VERSION/.match(line)
            submission.gi = line.split(":")[1].strip
          end
          if line =~ /DEFINITION\s+(.+)/
            submission.description = $1.strip
          end
          if line =~ /^LOCUS/ && line =~ /bp/
            line = line.split("bp")[0]
            length = line.split(" ")[-1]
            length.gsub!(" ", "")
            submission.sequence_length = length
          end
        end

        if File.exist?(JOBS_DIR + entry + "/" + "summary.txt")
          lines = File.readlines(JOBS_DIR + entry + "/" + "summary.txt")
          counter = 0

          loop do
            line = lines.shift
            break if line =~ /----/
            break if counter > 100
            counter = counter + 1
          end
          submission.phage_found = lines.length
        else
          submission.phage_found = 0
        end
	
        next if submission.gi.nil?
        submission.save!
      end
    end
  end
end
