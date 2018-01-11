namespace :fetch do

  desc "Fetch 108 genbank and fasta sequence files using NCBI API"
  task genbank_fasta: [:environment] do
    f = File.open('data/ncbi_ids', 'r').readlines
    counter = 0
    f.each do |line|
      if counter < 54
        contents = open("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=#{line}&rettype=fasta&retmode=text") { |io| io.read }
        output = File.open("data/" + line.gsub("\n", "") + ".fna", 'w')
        output.write(contents)
        output.close
      else
        contents = open("http://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?db=nuccore&id=#{line}&rettype=gbwithparts&retmode=text") { |io| io.read }
        output = File.open("data/" + line.gsub("\n", "") + ".gbk", 'w')
        output.write(contents)
        output.close
      end
      counter = counter + 1
    end
  end

  task rename: [:environment] do
    Dir.foreach("data/") do |d|
      if /\.gbk/.match(d) || /\.fna/.match(d)
        File.rename("data/" + d, "data/" + d.gsub("\n", ""))
      end
    end
  end

end