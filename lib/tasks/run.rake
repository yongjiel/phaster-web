namespace :run do

  desc "Run genomes in bulk from a fasta files or genbank files"
  task bulk_genomes: [:environment] do

    Dir.foreach("./data") do |d|

      f = File.open("data/" + d, 'r')
      if /\.gbk/.match(d)
        @submission = Submission.new(category: "upload", sequence: f)
        @submission.status = 'validating'

        if @submission.save
          @submission.queue_phaster
        end

      elsif /\.fna/.match(d)
        fasta = f.read
        @submission = Submission.new(category: "text")
        @submission.status = 'validating'
        @submission.add_sequence_from_text(fasta)
        @submission.sequence_file_name = d

        if @submission.save
          @submission.queue_phaster
        end

      end
    end

  end
end