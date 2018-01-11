class Contigs
  include Enumerable

  attr_reader :submission, :job_id, :contigs

  @regions_loaded = false

  def initialize(submission)
    @submission = submission
    @job_id = submission.job_id
    @contigs = {}
    read_contig_data
  end

  def read_contig_data
    contigs_file_path = File.join(@submission.job_dir, @job_id+'_contig_positions.txt')
    if File.exists?(contigs_file_path)
      File.readlines(contigs_file_path).each do |line|
        fields = line.split("\t").map { |f| f.strip.sub( /^>/, '') }
        @contigs[fields[0]] = Contig.new(self,
          name: fields[0],
          concat_start: fields[1].to_i,
          concat_end: fields[2].to_i,
          length: fields[3].to_i
        )
      end
    end
  end

  def each(&block)
    @contigs.values.each(&block)
  end


  def convert_concat_position(position)
    contig = contig_for_concat_position(position)
    if contig
      position - contig.concat_start + 1
    end
  end

  def contig_for_concat_position(position)
    self.find { |c| c.concat_range.include?(position) }
  end

  def contig_for_region_number(region_number)
    self.find { |c| c.region_numbers.include?(region_number.to_i) }
  end

  def [](key)
    @contigs.send(key)
  end

  def to_h
    @contigs
  end

  # filtered will only export contigs that have phage regions
  def to_json(filtered=false)
    contigs_to_export = filtered ? self.select { |c| c.region_numbers.present? }: self.to_a
    contigs_to_export.map(&:to_h).to_json
  end

  def load_region_info
    if @contigs.present? && !@regions_loaded
      summary = @submission.parse_summary
      if summary[:regions].present?
        @regions_loaded = true
        summary[:regions].each do |region|
          region_num = region[:region].to_i
          # contig_name = region[:region_position].sub(/^>/, '').sub(/:.*/, '')
          contig_name = region[:region_position].sub(/^>/, '').split(":")[0..-2].join(":")
          if @contigs[contig_name].present?
            @contigs[contig_name].add_region_number(region_num)
          else
            while (contig_name.include?(":"))
              contig_name = contig_name.split(":")[0..-2].join(":")
              if @contigs[contig_name].present?
                @contigs[contig_name].add_region_number(region_num)
                break
              end
            end

          end

        end
      end
    end
  end

  # convert

end


# Using a class for contig details to provide lazy loading of region information to contigs
class Contig
  attr_accessor :name, :concat_start, :concat_end, :length, :region_numbers, :regions

  def initialize(contigs, params = {})
    @contigs = contigs
    params.each { |k,v| send("#{k}=", v) }
    # Currently region details are added in the parse_chart function
    # We could parse this info at the same time as parsing the region numbers
    @regions = []
  end

  def to_h
    {
      name: name,
      concat_start: concat_start,
      concat_end: concat_end,
      concat_rang: concat_range,
      length: length,
      region_numbers: get_region_numbers,
      regions: regions
    }
  end

  def concat_range
    self.concat_start..self.concat_end
  end

  def add_region_number(region_number)
    @region_numbers ||= []
    @region_numbers << region_number
  end

  def region_numbers
    @region_numbers ||= get_region_numbers
  end

  def get_region_numbers
    if @region_numbers.blank?
      @contigs.load_region_info
    end
    @region_numbers || []
  end

end
