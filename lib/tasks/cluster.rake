require 'net/ssh'

namespace :cluster do
  
  # Check whether botha1 cluster is available and in good working order.
  task :check => [:environment] do
    hostname = "botha1.cs.ualberta.ca"
    username = "prion"
    keys = ['/apps/phaster/.ssh/botha', '~/.ssh/id_rsa'] # private keys to test (not all the files need to exist)
    
    begin
      ssh = Net::SSH.start(hostname, username, :keys => keys, :auth_methods => ['publickey']) # Only try public key authentication.
    rescue
      puts "Unable to connect to #{hostname} using #{username}"
      exit(1)
    end

    # Can qsub command be found?
    res = ssh.exec!('which qsub')
    if res =~ /no qsub in/
      puts "Could not find qsub command!"
      exit(1)
    else
      puts "qsub: ok"
    end

    # Are there any cluster child nodes that are alive?
    res = ssh.exec!('alive')
    c = 0
    res.split("\n").each { |line|
      c += 1
    }
    puts "#{c} child nodes available"
    if c == 0
      puts "No child nodes can be found!"
      exit(1)
    end
    
    ssh.close

    puts "Cluster appears to be ok"
    
  end
  
end
