module MechFarmer
require 'rubygems'
require 'net/ssh'
require 'net/ping'

  class Inventory
    class << self

      def set_dbfile(file)
        puts "creating dbfile"
        @@dbfile = File.open(file, 'w')
      end

      def set_errors_file(file)
        @@errors_file = File.open(file, 'w')
      end

      def dbfile
        if not defined? @@dbfile
          set_dbfile 'cti_inventory.yaml'
          return @@dbfile
        else
          return @@dbfile
        end
      end
      def errors_file 
        if not defined? @@errors_file
          set_errors_file 'cti_inventory_errors.txt'
          return @@errors_file
        else
          return @@errors_file
        end
      end
    end
  end

  class RemoteHost

    attr_reader :session

    def initialize(ip)
      @ip = ip
      begin
        @session = Net::SSH.start(ip, 'root', :timeout => 2)
        @session.exec! "hostname"
      rescue Exception
        @session = nil
      end
    end

    def alive?
      pe = Net::PingExternal.new(@ip)
      pt = Net::PingTCP.new(@ip,port=80,timeout=0.5)
      return true if pe.ping or pt.ping
      false
    end

    def hostname
      hostname = nil
      begin
        output = @session.exec! "hostname"
        hostname = output.chomp
      rescue Exception => e
        return nil
      end
      return hostname 
    end

    def root_ssh_pubkeys
      keys = []
      begin
        output  = @session.exec!('cat $HOME/.ssh/authorized_keys')
        if not output.nil?
          output.each_line do |line|
            keys << line.strip.chomp if not line.strip.chomp.empty?
          end
        end
      rescue
        ""
      end
      return keys
    end

    def routes
      routes = []
      begin
        output = @session.exec! "route -n"
        if not output.nil?
          output.each_line do |l|
            routes << l if l !~ /^(Kernel|Destination)/
          end
        end
      rescue
          ""
      end
      return routes
    end

    def users
      users = []
      begin
        output = @session.exec!("cat /etc/passwd")
        if not output.nil?
          output.each_line do |l|
            users << l.split(":")[0]
          end 
        end
      rescue
        ""
      end
      return users
    end

    def startup_services
      services = []
      begin
        output = @session.exec!("LANG=POSIX chkconfig --list|grep '3:on.*5:on'")
        if not output.nil?
          output.each_line do |l|
            services << l.split[0]
          end 
        end
      rescue
        ""
      end
      return services
    end


    def net_devices
      net_devices = []
      begin
        output = @session.exec!("cat /proc/net/dev")
        if not output.nil?
          output.each_line do |l|
            net_devices << l.split[0].gsub(/:.*/,"") if l !~ /^(Inter|\s*face)/
          end 
        end
      rescue
        ""
      end
      return net_devices
    end

    def ipv4_address
      ipv4_addresses = {}
      begin
        output = @session.exec!("ifconfig -a |grep 'inet addr:'")
        if not output.nil?
          output.each_line do |l|
            l =~ /addr:(.*?) .+Mask:(.*)$/
            addr = $1
            mask = $2
            ipv4_addresses[addr] = {}
            ipv4_addresses[addr]['mask'] = mask
          end 
        end
      rescue
        ""
      end
      return ipv4_addresses
    end

    def firewall_policy
      policy = {}
      begin
        output = @session.exec!("iptables -L -n|grep 'Chain INPUT \(policy'")
        if not output.nil?
          output.chomp =~ /policy (.*)\)/
          policy['input'] = $1
        end
        output = @session.exec!("iptables -L -n|grep 'Chain OUTPUT \(policy'")
        if not output.nil?
          output.chomp =~ /policy (.*)\)/
          policy['output'] = $1
        end
        output = @session.exec!("iptables -L -n|grep 'Chain FORWARD \(policy'")
        if not output.nil?
          output.chomp =~ /policy (.*)\)/
          policy['forward'] = $1
        end
      rescue
        ""
      end
      return policy
    end
  end #clsas
end # module


