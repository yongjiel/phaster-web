require 'csv'

namespace :stats do
  
  task :daily => [:environment] do
    
    matched_submissions = Submission.where('updated_at > "2016-11-25"')
      # Some jobs were deleted that were submitted Nov 15th to 25th, 2016, and a few before
      # that. So here we will only measure stats after that.
    
    puts("Number of submissions since 2016-11-25:")
    puts(matched_submissions.count)
    
    created_1 = matched_submissions.group("year(created_at)").group("month(created_at)").group("day(created_at)").count
    created = Hash.new
    created_1.each do |key, val|
      created[Date.new(key[0],key[1],key[2])] = val
    end
    
    updated_1 = matched_submissions.where(status: 'complete').group("year(updated_at)").group("month(updated_at)").group("day(updated_at)").count
    updated = Hash.new
    updated_1.each do |key, val|
      updated[Date.new(key[0],key[1],key[2])] = val
    end
    
    date_from  = Date.parse('2016-11-25')
    date_to    = Date.today
    (date_from..date_to).each do |d|
      created_str = ''
      if created.key?(d)
        created_str = created[d].to_s
      end
      
      updated_str = ''
      if updated.key?(d)
        updated_str = updated[d].to_s
      end
      
      puts d.to_s + "\t" + created_str + "\t" + updated_str
    end
    
  end
  
  
  task :timing => [:environment] do
    
    matched_submissions = Submission.where('updated_at > "2016-11-25" AND status = "complete"')
    
    matched_submissions.each do |submission|
      log_file_path = File.join(submission.job_dir, submission.job_id+'.log')
      
      if File.exists?(log_file_path)
        
        times = {
          'start' => '',
          'gene_finding' => '',
          'ppt' => '',
          'faa' => '',
          'before_tRNAscan' => '',
          'phage_finder_tRNA_tmRNA_done_at' => '',
          'phage_finder_tRNA_tmRNA' => '',
          'copy_pep' => '',
          'copy_blast' => '',
          'blast_virus' => '',
          'phage_finder_and_checks_done_at' => '',
          'scan_start' => '',
          'scan' => '',
          'scan_done_at' => '',
          'blast_bac_start' => '',
          'mkdir' => '',
          'copy_non_hit_pro_region' => '',
          'call_blast_parallel_bac' => '',
          'copy_ncbi_out' => '',
          'call_remote_blast' => '',
          'blast_bac' => '',
          'blast_bac_done_at' => '',
          'read_vir_header' => '',
          'read_bac_header' => '',
          'annotation' => '',
          'annotation_plus_waiting' => '',
          'annotation_done_at' => '',
          'extract_protein' => '',
          'get_true_region' => '',
          'png' => '',
          'total' => ''
          }
        
        found_timing_messages = false
        File.readlines(log_file_path).each do |line|
          if !found_timing_messages && /TIMING MESSAGES/.match(line)
            found_timing_messages = true
            next
          end
          
          if found_timing_messages
            if m = /Start (?:Glimmer|FragGeneScan) at (\d+) sec/.match(line)
              times['start'] = m[1]
            elsif m = /(?:Glimmer|FragGeneScan) run time = (\d+) sec/.match(line)
              times['gene_finding'] = m[1]
            elsif m = /Generating ppt file took (\d+) sec/.match(line)
              times['ppt'] = m[1]
            elsif m = /Generating faa file took (\d+) sec/.match(line)
              times['faa'] = m[1]
            elsif m = /Elapsed before tRNA scanning = (\d+) sec/.match(line)
              times['before_tRNAscan'] = m[1]
            elsif m = /phage_finder.sh and tRNA_tmRNA() done at (\d+) sec/.match(line)
              times['phage_finder_tRNA_tmRNA_done_at'] = m[1]
            elsif m = /phage_finder.sh and tRNA_tmRNA() took (\d+) sec/.match(line)
              times['phage_finder_tRNA_tmRNA'] = m[1]
            elsif m = /copy pep file to cluster took (\d+) sec/.match(line)
              times['copy_pep'] = m[1]
            elsif m = /copy BLAST results from cluster took (\d+) sec/.match(line)
              times['copy_blast'] = m[1]
            elsif m = /Parallel BLASTing #{submission.job_id}.faa against the Phage virus DB took (\d+) seconds/.match(line)
              times['blast_virus'] = m[1]
            elsif m = /phage_finder and checks done at (\d+) sec/.match(line)
              times['phage_finder_and_checks_done_at'] = m[1]
            elsif m = /scan.pl started at (\d+) sec/.match(line)
              times['scan_start'] = m[1]
            elsif m = /scan.pl took (\d+) sec/.match(line)
              times['scan'] = m[1]
            elsif m = /scan.pl done at (\d+) sec/.match(line)
              times['scan_done_at'] = m[1]
            elsif m = /Start parallel BLASTing non-hit regions at (\d+) sec/.match(line)
              times['blast_bac_start'] = m[1]
            elsif m = /call_remote_blast.sh: mkdir on cluster via SSH took (\d+) sec/.match(line)
              times['mkdir'] = m[1]
            elsif m = /call_remote_blast.sh: copy ..\/#{submission.job_id}.faa.non_hit_pro_region to cluster took (\d+) sec/.match(line)
              times['copy_non_hit_pro_region'] = m[1]
            elsif m = /call_remote_blast.sh: run call_blast_parallel.pl on cluster via SSH took (\d+) sec/.match(line)
              times['call_blast_parallel_bac'] = m[1]
            elsif m = /call_remote_blast.sh: copy ..\/ncbi.out.non_hit_pro_region from cluster took (\d+) sec/.match(line)
              times['copy_ncbi_out'] = m[1]
            elsif m = /call_remote_blast.sh took (\d+) sec/.match(line)
              times['call_remote_blast'] = m[1]
            elsif m = /Parallel BLASTing non-hit regions took (\d+) sec/.match(line)
              times['blast_bac'] = m[1]
            elsif m = /Parallel BLASTing non-hit regions done at (\d+) sec/.match(line)
              times['blast_bac_done_at'] = m[1]
            elsif m = /read in \/apps\/phaster\/phaster-app\/DB\/prophage_virus_header_lines.db, time (\d+) seconds/.match(line)
              times['read_vir_header'] = m[1]
            elsif m = /read in \/apps\/phaster\/phaster-app\/DB\/bacteria_all_select_header_lines.db , time (\d+) seconds/.match(line)
              times['read_bac_header'] = m[1]
            elsif m = /Finish annotation.pl in (\d+) seconds/.match(line)
              times['annotation'] = m[1]
            elsif m = /annotation.pl plus waiting took (\d+) sec/.match(line)
              times['annotation_plus_waiting'] = m[1]
            elsif m = /annotation.pl done at (\d+) sec/.match(line)
              times['annotation_done_at'] = m[1]
            elsif m = /extract_protein.pl took (\d+) sec/.match(line)
              times['extract_protein'] = m[1]
            elsif m = /get_true_region.pl took (\d+) sec/.match(line)
              times['get_true_region'] = m[1]
            elsif m = /make_png.pl took (\d+) sec/.match(line)
              times['png'] = m[1]
            elsif m = /Program finished, taking (\d+) seconds!/.match(line)
              times['total'] = m[1]
            end
          end
        end
        
        # Output times
        if times['total'] != '' # and times['blast_bac'] != '' # and times['blast_virus'] != ''
          puts submission.job_id + "\t" + times['blast_virus'] + "\t" + times['blast_bac'] + "\t" + times['total']
        end
        
      end
      
    end
  end
  
end
