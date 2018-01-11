require 'sidekiq/api'
require 'fileutils'

class Submission < ActiveRecord::Base

  has_many :batches, through: :batch_submissions, dependent: :destroy
  has_many :batch_submissions

  SECRET_ID_LENGTH = 5
  MAX_SEQ_LENGTH = 30000000
  JOBS_DIR = Rails.root.join('public', 'jobs')
  CATEGORIES = %w(identifier upload text)
  STATES = %w(validating queued running complete failed)
  FINALIZED_STATES = %w[ complete failed ]
  SEQUENCE_TYPES = %w(fasta genbank)
  
  # Summary columns keys with display name and legend definitions
  SUMMARY_DEFS = { :region => ["Region", "The number assigned to the region."], 
                   :region_length => ["Region Length", "The length of the sequence of that region (in bp)."], 
                   :completeness => ["Completeness", "A prediction of whether the region contains a intact or incomplete prophage based on the above criteria."],
                   :specific_keyword => ["Specific Keyword", "The specific phage-related keyword(s) found in protein name(s) in the region."],
                   :region_position => ["Region Position", "The start and end positions of the region on the bacterial chromosome."],
                   :trna_num => ["# tRNA", "The number of tRNA genes present in the region."],
                   :score => ["Score", "The score of the region based on the above criteria."],
                   :total_protein_num => ["# Total Proteins", "The number of ORFs present in the region."], 
                   :phage_hit_protein_num => ["# Phage Hit Proteins", "The number of proteins in the region with matches in the phage protein database."],
                   :hypothetical_protein_num => ["# Hypothetical Proteins", "The number of hypothetical proteins in the region without a match in the database."],
                   :phage_hypo_protein_percentage => ["Phage + Hypothetical Protein %", "The combined percentage of phage proteins and hypothetical proteins in the region."],
                   :bacterial_protein_num => ["# Bacterial Proteins", "The number of proteins in the region with matches in the nrfilt database."],
                   :att_site_showup => ["Attachment Site", "The putative phage attachment site."],
                   :phage_species_num => ["# Phage Species", "The number of different phages that have similar proteins to those in the region."],
                   :most_common_phage_name => ["Most Common Phage", "The phage(s) with the highest number of proteins most similar to those in the region."],
                   :first_most_common_phage_num => ["First Most Common Phage #", "The highest number of proteins in a phage most similar to those in the region."],
                   :first_most_common_phage_percentage => ["First Most Common Phage %", "The percentage of proteins in # Phage Hit Proteins that are most similar to the Most Common Phage proteins."],
                   :most_common_phage_num => ["First Most Common Phage #", "The highest number of proteins in a phage most similar to those in the region."],
                   :most_common_phage_percentage => ["First Most Common Phage %", "The percentage of proteins in # Phage Hit Proteins that are most similar to the Most Common Phage proteins."],
                   :gc_percentage => ["GC %", "The percentage of GC nucleotides of the region."] }
  # Which columns to show on the summary show page
  SUMMARY_COLS = [:region, :region_length, :completeness, :score, :total_protein_num,
                  :region_position, :most_common_phage_name, :gc_percentage]

  # Which columns to show on the details show page
  DETAILS_COLS = {:cds_position => "CDS Position", 
                  :blast_hit => "BLAST Hit", 
                  :evalue => "E-Value", 
                  :prophage_pro_seq => "Sequence", 
                  }

  has_attached_file :sequence, path: "#{JOBS_DIR}/:job_id/:sequence_name"
  Paperclip.interpolates :job_id do |attachment, style|
    attachment.instance.job_id
  end
  Paperclip.interpolates :sequence_name do |attachment, style|
    attachment.instance.sequence_name
  end
  validates_attachment :sequence, presence: true, if: Proc.new { |s| ['upload', 'text'].include?(s.category) }

  do_not_validate_attachment_file_type :sequence

  before_validation :generate_job_id, on: :create
  before_validation :parse_sequence_length, on: :create
  before_create :parse_ids_and_description,  if: Proc.new { |s| ['upload', 'text'].include?(s.category) }

  before_save :create_job_dir
  before_save :move_contig_pos_file
  after_destroy :delete_job_dir

  validates :status, inclusion: { in: STATES }
  validates :category, inclusion: { in: CATEGORIES }
  # validates :sequence_type, inclusion: { in: SEQUENCE_TYPES }
  validates :job_id, presence: true, uniqueness: true
  validate :check_sequence, on: :create

  validates_attachment_size :sequence, :less_than => 26.megabytes, :if => "fasta?"

  validate :check_fasta_min_length, on: :create, :if => "fasta?"
  validate :check_DNA_content, on: :create, :if => "fasta?"

  validate :check_identifier, if: Proc.new { |s| s.category == 'identifier' }

  validate :check_input_content
  

  def to_param
    self.job_id
  end

  # Generate private URL
  def generate_job_id
    self.job_id ||= self.category_identifier ? self.accession : 'ZZ_' + SecureRandom.hex(SECRET_ID_LENGTH)
  end

  def generate_contig_fileid
    self.contig_fileid = 'CC_' + SecureRandom.hex(SECRET_ID_LENGTH)
  end

  def category_identifier
    self.category == 'identifier'
  end

  def category_upload
    self.category == 'upload'
  end

  def category_text
    self.category == 'text'
  end

  def sequence_name
    if self.sequence_type == 'fasta'
      "#{self.job_id}.fna"
    else
      "#{self.job_id}.gbk"
    end
  end

  def finalized?
    FINALIZED_STATES.include?(self.status)
  end

  def failed?
    self.status == 'failed'
  end

  def filter_contigs

    seq_file = self.sequence.queued_for_write[:original]
    FileUtils.cp(seq_file.path, File.join(JOBS_DIR, self.contig_fileid+'_original.fna'))

    temp_readfile = File.open(File.join(JOBS_DIR, self.contig_fileid+'_read.fna'), "w")

    full_seq = ""
    header = ""

    seq_lines = File.readlines(seq_file.path)
    seq_lines.each do |line|
      line.gsub!("\n", "")
      if line =~ /^>/ || line[seq_lines.last]
 
        if line[seq_lines.last]
          full_seq+=line
        end

        if !full_seq.empty? && !header.empty?
          if full_seq.length > 2000
            temp_readfile.puts(header + "\n")
            temp_readfile.puts(full_seq + "\n")
          end
        end
        header = line + "\n"
        full_seq = ""

      else
        full_seq+=line

      end
    end

    temp_readfile.close

    FileUtils.mv(File.join(JOBS_DIR, self.contig_fileid+'_read.fna'), seq_file.path)
    FileUtils.cp(seq_file.path, File.join(JOBS_DIR, self.contig_fileid+'_filtered.fna'))

  end

  def organise_contigs

    seq_file = self.sequence.queued_for_write[:original]
    
    contigs_pos_name = File.join(JOBS_DIR, self.contig_fileid+'_contig_positions.txt')
    contig_positions = File.open(contigs_pos_name, 'w')
    
    contig_seq = ""
    contig_info = ""
    contig_pos = 0 

    first_line = 1

    file_lines = File.readlines(seq_file.path)
    file_lines.each do |line|

      line.gsub!("\n", "")
      if line =~ /^>/ || line[file_lines.last]
        line.gsub!(">", "") if line =~ /^>/
        if line[file_lines.last]
          contig_seq += line
        end

        if !contig_seq.empty?
          if first_line==1
            contig_info += "1\t"
            first_line = 0
            contig_pos += contig_seq.length
          else
            contig_info += contig_pos.to_s+"\t"
            contig_pos += contig_seq.length-1
          end

          contig_info += contig_pos.to_s+"\t"
          contig_info += contig_seq.length.to_s
          contig_positions.puts(contig_info+"\n")
          contig_pos += 1
        end
        contig_seq = ""
        contig_info = line+"\t"
      else
        line.gsub!(" ", "")
        contig_seq += line
      end

    end

    contig_positions.close

  end


  def concatenate_contigs

    self.filter_contigs
    self.organise_contigs

    temp_file = File.open(File.join(JOBS_DIR, self.contig_fileid+'_new.fna'), "w")
    temp_file.puts(">gi|00000000|ref|NC_000000| Genome; Raw sequence\n")

    seq_file = self.sequence.queued_for_write[:original]
    file_lines = File.readlines(seq_file.path)
    # File.foreach(seq_file.path) do |line|
    file_lines.each do |line|
      line.gsub!("\n", "")
      temp_file.puts(line) unless line =~ /^>/

    end

    temp_file.puts("\n")
    temp_file.close
    
    FileUtils.mv(File.join(JOBS_DIR, self.contig_fileid+'_new.fna'), seq_file.path)

  end

  def display_status(queue="default")
    text = self.status.capitalize
    text = "#{self.display_queue_position(queue)}" if self.status == 'queued'
    text = text + '...' unless self.finalized?
    text
  end

  def queue_position(queue="default")
    queue = Sidekiq::Queue.new(queue)
    jids = queue.map { |j| j.jid }.reverse
    jids.index(self.sidekiq_id)
  end

  def display_queue_position(queue="default")
    position = self.queue_position(queue)
    if position.present?
      position += 1
      "#{position} " + 'submission'.pluralize(position) + " ahead of yours"
    else
      "You're next!"
    end
  end

  # Parse summary data into hash for results
  def parse_summary

    # Break into major sections
    content = File.read(self.summary_path).split(/\n\n\n/).map(&:strip)
    # Store data in hash

    summary = {}
    summary[:criteria] = content[0]

    # Parse regions block line by line
    regions = content[2].split(/\n+/).map(&:strip)

    # Special check here for result files missing the header
    if regions[0].start_with? "REGION"
      detail_content = File.read(self.detail_path).split(/\n\n/).map(&:strip)
      summary[:title] = detail_content.shift
    else
      summary[:title] = regions.shift
    end

    summary[:headers] = regions.shift.split(/\s{3,}/).map { |i| i.gsub(/\+/, "_").gsub(/\(.+\)/, "") }
    summary[:regions] = []

    # Keep track of region counts
    summary[:intact] = 0
    summary[:questionable] = 0
    summary[:incomplete] = 0
    # Store regions as an array of hashes using the headers as keys
    regions.each do |line|
      line.strip!
      if line =~ /^\d/
        region = {}
        line.split(/\s{3,}/).each_with_index do |col, i|
          region[summary[:headers][i].parameterize.underscore.to_sym] = col
        end
        score = region[:completeness].match(/\d+/)[0]
        if score.present? && score.to_i < 70
          summary[:incomplete] += 1
        elsif score.present? && score.to_i > 90
          summary[:intact] += 1
        elsif score.present?
          summary[:questionable] += 1
        end
        summary[:regions] << region
      end
    end

    # Get region DNA from NA.txt
    summary[:region_dna] = File.read("#{JOBS_DIR}/#{self.job_id}/region_DNA.txt").split(/\n\n\n/).map(&:strip)

    summary
  end

  # Parse details data into hash for results
  def parse_details
    # Break into major sections
    content = File.read(self.detail_path).split(/\n\n/).map(&:strip)
    # Store data in hash
    details = {}
    details[:title] = content.shift
    details[:headers] = content.shift.split(/\n/)[0].split(/\s+/).map { |i| i.parameterize.underscore.to_sym }

    # Store regions as array of hashes
    details[:regions] = {}
    content.each do |region_group|
      region_lines = region_group.split(/\n+/).map(&:strip)
      name = region_lines.shift.gsub(/####/, "").strip

      # Store sequences as array of hashes for each region
      sequences = []
      region_lines.each do |line|
        sequence = {}
        line.split(/\s{3,}/).each_with_index do |col, i|
          sequence[details[:headers][i]] = col
        end

        sequences << sequence
      end

      # details[:regions][name.parameterize.underscore.to_sym] = sequences
      details[:regions][name] = sequences
    end

    details
  end

  # Parse chart data into hash for results
  def parse_chart
    # Break into major sections
    content = File.read(self.png_input_path).split(/\n\n\n/).map(&:strip)
    rna_content = File.read(self.png_input_rna_path).gsub(/\r/, "\n").split(/\n\n\n/).map(&:strip)

    # Store data in hash
    chart = {}
    sections = content.shift.split(/\n+/).map(&:strip)
    regions = content.shift.split(/\n+/).map(&:strip)

    # Weird bit here because sometimes the results are in different places...
    if sections[0].start_with? ">"
      title = sections.shift
      chart[:name] = title[/>\s*(.*)\./, 1].to_s.gsub(/\[.+\]/, "").strip
      chart[:length] = title[/\.\s*(\d+)\s*$/, 1].to_i
      chart[:headers] = sections.shift.split(/\s{3,}/).map { |i| i.strip.parameterize.underscore.to_sym }
    else

      rna_content_lines = rna_content.shift.split(/\n+/).map(&:strip)
      
      first_line = rna_content_lines[0].strip

      chart[:name] = first_line.split.tap(&:pop)
      puts(chart[:name])
      chart[:length] = first_line.split.pop.to_i
      chart[:headers] = rna_content_lines[1].split(/\s{3,}/).map { |i| i.strip.parameterize.underscore.to_sym }

    end

    chart[:regions] = {}
    ranges = {}

    regions.each_with_index do |line, i|
      data = line.split(/\s{3,}/).map(&:strip)
      region = {}
      region[:number] = data[1]
      region[:start] = data[2]
      region[:end] = data[3]
      region[:completeness] = data[4]
      region[:gc] = data[5]
      region[:sequences] = []
      region[:contig] = self.contigs? ? data[6] : nil

      # Keep track of the region ranges so we know where to put the sequences
      ranges[("region_" + data[1]).to_sym] = (region[:start].to_i..region[:end].to_i)

      chart[:regions][("region_" + data[1]).to_sym] = region
    end

    sections.each do |line|
      data = line.split(/\s{3,}/).map(&:strip)
      section = {}
      section[:from] = data[1]
      section[:to] = data[2]
      section[:strand] = data[3]
      section[:match] = data[4].parameterize.underscore
      section[:protein_name] = data[5]
      section[:evalue] = data[6]
      section[:sequence] = data[7]
      section[:contig] = self.contigs? ? data[8] : nil

      # Figure out which region to add this sequence to
      ranges.each do |key, val|
        if (section[:contig] == chart[:regions][key][:contig]) && ( val.include?((section[:to].to_i..section[:from].to_i)) )
          chart[:regions][key][:sequences] << section
          section[:region] = key.to_s
          break
        end
      end

    end

    if self.contigs?
      # Add summary of region info to contigs
      self.contig_data.each do |contig|
        contig.region_numbers.each do |region_num|
          orig_region = chart[:regions]["region_#{region_num}".to_sym]
          if orig_region
            region = orig_region.clone
            region[:sequences] = region[:sequences].length
            contig.regions << region
          end
        end
      end
      chart[:contigs] = self.contig_data
    end

    chart

  end

  def parse_number_of_phage
    if File.exist?(self.summary_path)
      lines = File.readlines(self.summary_path)
      counter = 0

      loop do
        line = lines.shift
        break if line =~ /----/
        break if counter > 100
        counter = counter + 1
      end
      lines.length
    else
      0
    end
  end

  def parse_contigs

    self.update_results_contigs(self.summary_path, "-")
    self.update_results_contigs(self.detail_path, "..")
    self.update_results_contigs(self.phage_regions_path, "-") if File.exist?(self.phage_regions_path)

    self.update_png_input_contig_positions(self.png_input_path)
    self.update_png_input_contig_positions(self.png_input_rna_path)
  end

  def update_png_input_contig_positions(filepath)
    orig_lines = File.readlines(filepath)
    new_lines = []

    # Replace region positions with contig positions
    orig_lines.each do |line|
      # Header
      new_line = line.sub(/(^\s*from\s+to\s+.*$)/) do
        "#{$1}   contig"
      end
      # Sections
      new_line = new_line.sub(/(^section\s+)(\d+)(\s+)(\d+)(.*)/) do
        new_from = self.contig_data.convert_concat_position($2.to_i)
        new_to = self.contig_data.convert_concat_position($4.to_i)
        contig = self.contig_data.contig_for_concat_position($2.to_i)
        contig_name = contig.present? ? contig.name : "Unknown_Contig"
        "#{$1}#{new_from}#{$3}#{new_to}#{$5}   #{contig_name}"
      end
      # Regions
      new_line = new_line.sub(/(^region\s+\d+\s+)(\d+)(\s+)(\d+)(.*)/) do
        new_from = self.contig_data.convert_concat_position($2.to_i)
        new_to = self.contig_data.convert_concat_position($4.to_i)
        contig = self.contig_data.contig_for_concat_position($2.to_i)
        contig_name = contig.present? ? contig.name : "Unknown_Contig"
        "#{$1}#{new_from}#{$3}#{new_to}#{$5}   #{contig_name}"
      end
      new_lines << new_line
    end

    # Write out updated file
    File.open(filepath, "w") do |file|
      file.puts(new_lines)
    end
  end

  def update_results_contigs(filepath, delimiter)

    results_content = File.read(filepath)
    new_content = results_content

    if delimiter=="-"
      regex = /\d+\-\d+/
    elsif delimiter==".."
      regex = /\d+\.\.\d+/
    end

    if filepath == self.detail_path
      region_regex = /region \d+.*\n.*\d+\.\.\d+/
      results_content.scan(region_regex).each do |region|

        region_name = region.scan(/region \d+/).first

        first_region = region.scan(regex)
        split_region = first_region.split(delimiter)
        lower_pos = first_region[0].to_i
        upper_pos = first_region[1].to_i

        contig_range = self.parse_contig_positions(lower_pos, upper_pos, delimiter)

        contig_name = contig_range.split(":")[0..-2].join(":")

        new_name = region_name.to_s + ", " + contig_name.to_s
        new_region = region.gsub(region_name, new_name)

        new_content.gsub!(region, new_region)

      end

    end

    results_content.scan(regex).each do |range|

      split_range = range.split(delimiter)

      lower_pos = split_range[0].to_i
      upper_pos = split_range[1].to_i

      contig_range = self.parse_contig_positions(lower_pos, upper_pos, delimiter)

      if filepath == self.detail_path
        contig_range = contig_range.split(":")[-1]
      end

      new_content.gsub!(range, contig_range)

    end

    results_file = File.open(filepath, "w")
    results_file.puts(new_content)
    results_file.close

  end

  def parse_contig_positions(lower_pos, upper_pos, delimiter)

    new_from = self.contig_data.convert_concat_position(lower_pos.to_i)
    new_to = self.contig_data.convert_concat_position(upper_pos.to_i)
    contig = self.contig_data.contig_for_concat_position(lower_pos.to_i)
    contig_name = contig.present? ? contig.name : "Unknown_Contig"
    "#{$1}#{new_from}#{$3}#{new_to}#{$5}   #{contig_name}"

    contig_out = contig_name + ":" + new_from.to_s + delimiter
    contig_range = contig_out + new_to.to_s 


    return contig_range

  end

  def check_fasta_min_length

    if self.contigs?
      if self.sequence_length < 2000
        errors[:base] << "Your fasta input does not contain a contig longer than 2000 basepairs. At least 2 contigs must be longer than 2000 basepairs."
      end
    else
      if self.sequence_length < 1500
        errors[:base] << "Your fasta sequence is too short. The minimum length is 1500."
      end
    end

  end

  def check_input_content

    seq_file = self.sequence.queued_for_write[:original]

    case self.category
    when 'upload', 'text'

      seq_file = self.sequence.queued_for_write[:original]

      if !seq_file
        return
      end

      case self.sequence_type
      when 'genbank'

        accession = 0
        origin = 0
        File.readlines(seq_file.path).each do |line|
        # File.foreach(seq_file.path) do |line|
          line.strip!
          if line.include?("ACCESSION")
            accession = 1
          elsif line == "ORIGIN"
            origin = 1
            break
          end
        end

        if accession == 0
          errors[:base] << "Not a GBK file. A GBK file must include 'LOCUS', 'ACCESSION', and 'ORIGIN'. Please check!"
        end
        if origin == 0
          errors[:base] << "There is no DNA sequence in one or more of your GBK file entries. Plese check!"
        end

      when 'fasta'

        if self.sequence_length == 0
          errors[:base] << "There is no DNA sequence in your fasta input. Please check!"
        end

      end
    end
  end

  def replace_newline_characters
  
    seq_file = self.sequence.queued_for_write[:original]

    if !seq_file
      errors[:base] << "Invalid file format. File must be text only, in Fasta or GenBank format."
      return
    end

    seq_content = File.read(seq_file.path)

    seq_content.gsub!("\r\n", "\n")
    seq_content.gsub!("\r", "\n")

    replace_file = File.open(seq_file.path, "w")
    replace_file.puts(seq_content)
    replace_file.close

  end

  def parse_sequence_length

    case self.category
    when 'upload', 'text'

      nucleotide_counts = Array.new
      seq_file = self.sequence.queued_for_write[:original]
      if !seq_file
        errors[:base] << "Invalid file format. File must be text only, in Fasta or GenBank format."
        return
      end

      begin 
        first_line = File.open(seq_file.path, &:readline)

        adenine_count = 0
        guanine_count = 0
        cytosine_count = 0
        thymine_count = 0

        length = 0

        if first_line =~ /^>/ || self.contigs? || self.fasta?

          File.readlines(seq_file.path).each_with_index do |line, index|
            next if index == 0
            next if line[0]==">"

            length += line.length
          end

        elsif first_line =~ /^LOCUS/ && first_line =~ /bp/
          first_line = first_line.split("bp")[0]
          length = first_line.split(" ")[-1]
          length.gsub!(" ", "")
        end
      rescue
        errors[:base] << "Invalid file format. File must be text only, in Fasta or GenBank format."
        return
      end

      self.sequence_length = length
    end
  end

  def parse_ids_and_description
    seq_file = File.open( self.sequence.queued_for_write[:original].path )
    if self.genbank?
      loop do
        line = seq_file.gets
        if line =~ /DEFINITION\s+(.+)/
          self.description = $1.strip
        end
        if line =~ /VERSION\s+(\S+)\s+GI:(\d+)/
          self.accession ||= $1
          self.gi ||= $2
          break
        end
        break if line.nil?
      end

    elsif self.fasta?
      first_line = seq_file.gets
      if first_line =~ /gi\|(\d+)\|ref\|(.*?)\|\S*(.*)/
        self.gi = $1
        self.accession = $2
        self.description = $3.strip
      else
        self.description = first_line.sub('>', '').strip
      end
    end
    seq_file.close
  end

  def queue_phaster(priority="default")

    self.update!(status: 'queued')
    sidekiq_id = Sidekiq::Client.push('class' => SubmissionWorker, 'args' => [self.id], 'queue' => priority)
    self.update!(sidekiq_id: sidekiq_id)
   
  end

  def job_dir
    File.join(JOBS_DIR, self.job_id)
  end

  def log_path
    File.join(self.job_dir, "#{self.job_id}.log")
  end

  def process_path
    File.join(self.job_dir, "#{self.job_id}.process")
  end

  def fail_path
    File.join(self.job_dir, "fail.txt")
  end

  def success_path
    File.join(self.job_dir, "success.txt")
  end

  def summary_path
    File.join(self.job_dir, 'summary.txt')
  end

  def detail_path
    File.join(self.job_dir, 'detail.txt')
  end

  def image_path
    File.join(self.job_dir, 'image.png')
  end

  def png_input_path
    File.join(self.job_dir, 'png_input')
  end

  def png_input_rna_path
    File.join(self.job_dir, 'png_input_RNA')
  end

  def phage_regions_path
    File.join(self.job_dir, 'region_DNA.txt')
  end
  
  
  ### Intermediate files that can be deleted ###
  
  def predicted_genes_path
    File.join(self.job_dir, "#{self.job_id}.predict")
  end
  
  def predicted_genes_ptt_path
    File.join(self.job_dir, "#{self.job_id}.ptt")
  end
  
  def predicted_gene_aa_seqs_path
    File.join(self.job_dir, "#{self.job_id}.faa")
  end
  
  def tRNAscan_output_path
    File.join(self.job_dir, 'tRNAscan.out')
  end
  
  def tmRNA_aragorn_path
    File.join(self.job_dir, 'tmRNA_aragorn.out')
  end
  
  def extracted_tRNA_tmRNA_path
    File.join(self.job_dir, 'extract_RNA_result.txt.tmp')
  end
  
  def blast_results_against_phage_db_path
    File.join(self.job_dir, 'ncbi.out')
  end
  
  def genes_not_matched_to_phage_path
    File.join(self.job_dir, "#{self.job_id}.faa.non_hit_pro_region")
  end
  
  def blast_results_against_bacterial_db_path
    # Only genes in potential phage regions that were not matched to phage are searched
    # against the bacterial sequence DB.
    File.join(self.job_dir, 'ncbi.out.non_hit_pro_region')
  end
  
  def temporary_summary_path # Exact same contents as summary_path, but we will delete this one.
    File.join(self.job_dir, 'true_defective_prophage.txt')
  end
  
  # One possible path for directory named with accession number
  def accession_dir_path_1
    accession_string = self.accession
    if accession_string.nil? || accession_string.empty?
      accession_string = 'NC_000000'
    end
    File.join(self.job_dir, "#{accession_string}_dir")
  end
  
  # Another possible path for directory named with accession number
  def accession_dir_path_2
    File.join(self.job_dir, "NC_000000_dir")
  end
  
  ### End files that can be deleted ###
  
  
  
  def logger(text)
    File.open(self.log_path, 'a+') { |f| f.puts(text) }
  end

  # Check first line of sequence file to determine file type
  def check_sequence
    if self.category_identifier
      self.sequence_type = 'genbank'
    else
      begin
        seq_file = self.sequence.queued_for_write[:original]
        seq_content = File.read(seq_file.path)

        first_line = seq_file ? File.open(seq_file.path, &:readline) : ''
        if first_line =~ /^>/
          self.sequence_type = 'fasta'
          if first_line.length>1000
            errors[:base] << "Your header is too long. Please enter the sequence with a shorter header!"
          end
        elsif first_line =~ /^LOCUS/
          self.sequence_type = 'genbank'
        elsif seq_content.include?(">")
          errors[:base] << "The sequence header is not on the first line. Please check!"
        elsif !seq_content.empty?
          self.sequence_type = 'fasta'
          header = "> unkown " + Time.now.to_s
          seq_file_content = File.open(seq_file.path, 'w')
          seq_file_content.puts(header)
          seq_file_content.puts(seq_content)
          seq_file_content.close

        elsif seq_file
          errors[:base] << "Sequence type can not be determined"
          errors[:base] << "Not GenBank or FASTA input. A GenBank file must include 'LOCUS', 'ACCESSION', and 'ORIGIN'. FASTA input must include a DNA sequence. Header is optional."
        end

      rescue
        errors[:base] << "Invalid file format. File must be text only, in Fasta or GenBank format."
        return
      end


    end
  end


  def check_DNA_content
    iupac_chars = ["a", "c", "g", "t", "u", "r", "y", "s", "w", "k", "m", "b", "d", "h", "v", "n", ".", "-"]

    seq_file = self.sequence.queued_for_write[:original]
    file_lines = File.readlines(seq_file.path)
    file_lines = file_lines.reject{|s| s[0]==">"}
    seq = file_lines.join("")
    seq.downcase!
    seq.gsub!(/\s+/, "")
    seq.gsub!(/\/+$/, "") # trim trailing slashes

    seq.chars.each do |base|
      if !iupac_chars.include?(base)
        errors[:base] << "Invalid characters found in the DNA sequence. Please check the IUPAC nucleotide code!"
        return
      end
    end

  end



  def genbank?
    self.sequence_type == 'genbank'
  end

  def fasta?
    self.sequence_type == 'fasta'
  end

  def contigs?
    self.contigs
  end

  def add_sequence_from_text(text)
    if text.present?
       self.sequence = StringIO.new(text)
       self.sequence_file_name = 'fasta.fna'
    end
  end

  def gi_and_accession_from_identifier(identifier)
    if identifier.present?
      gi_search = Bio::NCBI::REST::ESearch.nucleotide(identifier)
      puts "GISEARCH"
      gi_search.each do |i|
        puts "I"
        puts "YY"+i+"YY"
      end
      if gi_search.count == 1
        self.gi = gi_search.first
        self.accession = Bio::NCBI::REST::EFetch.nucleotide(self.gi, 'acc')
      elsif gi_search.count > 1
        self.gi = gi_search.join(', ')
      else
        self.gi ='Not Found'
      end
    end
  end

  def create_job_dir
    FileUtils.mkdir_p(self.job_dir)
  end

  def delete_job_dir
    FileUtils.rm_r(self.job_dir) if File.exists?(self.job_dir) && self.job_id
  end

  def delete_contig_files
    if !self.contig_fileid
      return
    end

    FileUtils.rm(File.join(JOBS_DIR, self.contig_fileid+'_contig_positions.txt')) if File.exists?(File.join(JOBS_DIR, self.contig_fileid+'_contig_positions.txt'))
    FileUtils.rm(File.join(JOBS_DIR, self.contig_fileid+'_filtered.fna')) if File.exists?(File.join(JOBS_DIR, self.contig_fileid+'_filtered.fna'))
    FileUtils.rm(File.join(JOBS_DIR, self.contig_fileid+'_original.fna')) if File.exists?(File.join(JOBS_DIR, self.contig_fileid+'_original.fna'))
    FileUtils.rm(File.join(JOBS_DIR, self.contig_fileid+'_new.fna')) if File.exists?(File.join(JOBS_DIR, self.contig_fileid+'_new.fna'))
    FileUtils.rm(File.join(JOBS_DIR, self.contig_fileid+'_read.fna')) if File.exists?(File.join(JOBS_DIR, self.contig_fileid+'_read.fna'))

  end

  # If contigs - move contig positions file to job direcotry
  def move_contig_pos_file
    if !self.contig_fileid
      return
    end

    if File.exists?(File.join(JOBS_DIR, self.contig_fileid+'_contig_positions.txt'))
      FileUtils.mv(File.join(JOBS_DIR, self.contig_fileid+'_contig_positions.txt'), File.join(JOBS_DIR, self.job_id, self.job_id+'_contig_positions.txt'), :force => true)
    end
    if File.exists?(File.join(JOBS_DIR, self.contig_fileid+'_original.fna'))
      FileUtils.mv(File.join(JOBS_DIR, self.contig_fileid+'_original.fna'), File.join(JOBS_DIR, self.job_id, self.job_id+'_original.fna'), :force => true)
    end
    if File.exists?(File.join(JOBS_DIR, self.contig_fileid+'_filtered.fna'))
      FileUtils.mv(File.join(JOBS_DIR, self.contig_fileid+'_filtered.fna'), File.join(JOBS_DIR, self.job_id, self.job_id+'_filtered.fna'), :force => true)
    end

  end

  def contig_data
    @contig_data ||= Contigs.new(self)
  end

  def zip_data
    temp_file = Tempfile.new('temp')
    begin
      #Initialize the temp file as a zip file
      Zip::OutputStream.open(temp_file) { |zos| }

      Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip|
        zip.add('summary.txt', self.summary_path) if File.exist?(self.summary_path)
        zip.add('detail.txt', self.detail_path) if File.exist?(self.detail_path)
        # zip.add('image.png', self.image_path) if File.exist?(self.image_path)
        zip.add('phage_regions.fna', self.phage_regions_path) if File.exist?(self.phage_regions_path)
      end

      #Read the binary data from the file
      zip_data = File.read(temp_file.path)
    ensure
      temp_file.close
      temp_file.unlink
    end
    zip_data
  end

  def zip_data_name
    "#{self.job_id}.PHASTER.zip"
  end

  def check_identifier
    if self.gi.blank?
      errors[:base] << "An accession or gi number must be provided"
    elsif self.gi == 'Not Found'
      errors[:base] << "No record could be found for the accession/gi provided"
    elsif self.gi =~ /,/
      errors[:base] << "Multiple records were found: #{self.gi}"
    end
  end


  def count_nucleotides(seq = nil)
    if !seq
      seq = ""
      seq_file = self.sequence.queued_for_write[:original]
      file_lines = File.readlines(seq_file.path)
      file_lines = file_lines.reject{|s| s.include?(">")}
      seq = file_lines.join("")

    end

    if seq
      seq.downcase!
      self.adenine_count = seq.scan(/a/).count
      self.thymine_count = seq.scan(/t/).count
      self.cytosine_count = seq.scan(/c/).count
      self.guanine_count = seq.scan(/g/).count
    end
  end

  def count_nucleotides_from_upload

    if self.genbank?
      count_nucleotides
    elsif self.fasta?
      count_nucleotides
    end

  end

  def allowed_runtime
    # 3 * estimated_runtime
    max_time = 3.hour
    if self.sequence_length
      time = 1800 + self.sequence_length * 0.0003 # 30 minutes (1500 bp) to 3 hours (30 Mbp)
      [time, max_time].min.to_i
    else
      max_time
    end
  end

  # def estimated_runtime
  #   1.hour
  # end

end
