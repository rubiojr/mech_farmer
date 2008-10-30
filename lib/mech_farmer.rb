module MechFarmer
require 'rubygems'
require 'net/ssh'
require 'net/ping'

  class Inventory

    attr_accessor :dbfile

    def initialize
      @items = {}
    end
    
    def add_item(hash)
      @items[hash.keys[0]] = hash.values[0]
      @dbfile = 'inventory.yaml'
    end

    def write
      File.open(@dbfile, 'w') do |f|
        f.puts @items.to_yaml
      end
    end

  end

  class RemoteHost

    attr_reader :session
    attr_writer :hostname, :root_ssh_pubkeys, :routes, :users
    attr_writer :startup_services, :net_devices, :ipv4_addresses
    attr_writer :firewall_policy

    def initialize(ip)
      @ip = ip
      @hostname = nil
      @root_ssh_pubkeys = nil
      @routes = nil
      @users = nil
      @startup_services = nil
      @net_devices = nil
      @ipv4_addresses = nil
      @firewall_policy = nil
    end

    def farm
      begin
        @session = Net::SSH.start(@ip, 'root', :timeout => 2)
        @session.exec! "hostname"
      rescue Exception
        @session = nil
        return false
      end
      @hostname = hostname
      @root_ssh_pubkeys = root_ssh_pubkeys
      @routes = routes
      @users = users
      @startup_services = startup_services
      @net_devices = net_devices
      @ipv4_addresses = ipv4_addresses
      @firewall_policy = firewall_policy
      @session.close
      @session = nil
      return true
    end

    def alive?
      pe = Net::PingExternal.new(@ip)
      pt = Net::PingTCP.new(@ip,port=80,timeout=0.5)
      return true if pe.ping or pt.ping
      false
    end

    # returns a string
    def hostname
      return @hostname if not @hostname.nil?
      begin
        output = @session.exec! "hostname"
        @hostname = output.chomp
      rescue Exception => e
        return nil
      end
      return @hostname 
    end

    # returns an array
    def root_ssh_pubkeys
      return @root_ssh_pubkeys if not @root_ssh_pubkeys.nil?
      @root_ssh_pubkeys = []
      begin
        output  = @session.exec!('cat $HOME/.ssh/authorized_keys')
        if not output.nil?
          output.each_line do |line|
            @root_ssh_pubkeys << line.strip.chomp if not line.strip.chomp.empty?
          end
        end
      rescue
        ""
      end
      return @root_ssh_pubkeys
    end

    # returns an array
    def routes
      return @routes if not @routes.nil?
      @routes = []
      begin
        output = @session.exec! "route -n"
        if not output.nil?
          output.each_line do |l|
            @routes << l if l !~ /^(Kernel|Destination)/
          end
        end
      rescue
          ""
      end
      return @routes
    end

    # returns an array
    def users
      return @users if not @users.nil?
      @users = []
      begin
        output = @session.exec!("cat /etc/passwd")
        if not output.nil?
          output.each_line do |l|
            @users << l.split(":")[0] if not l =~ /^\s*#.+?$/
          end 
        end
      rescue
        ""
      end
      return @users
    end

    # returns an array
    def startup_services
      return @startup_services if not @startup_services.nil?
      @startup_services = []
      begin
        output = @session.exec!("LANG=POSIX chkconfig --list|grep '3:on.*5:on'")
        if not output.nil?
          output.each_line do |l|
            @startup_services << l.split[0]
          end 
        end
      rescue
        ""
      end
      return @startup_services
    end

    # returns an array
    def net_devices
      return @net_devices if not @net_devices.nil?
      @net_devices = []
      begin
        output = @session.exec!("cat /proc/net/dev")
        if not output.nil?
          output.each_line do |l|
            @net_devices << l.split[0].gsub(/:.*/,"") if l !~ /^(Inter|\s*face)/
          end 
        end
      rescue
        ""
      end
      return @net_devices
    end

    # returns a dict
    # {
    #  address1 : {mask}
    #  address2 : {mask}
    # }
    def ipv4_addresses
      return @ipv4_addresses if not @ipv4_addresses.nil?
      @ipv4_addresses = {}
      begin
        output = @session.exec!("ifconfig -a |grep 'inet addr:'")
        if not output.nil?
          output.each_line do |l|
            l =~ /addr:(.*?) .+Mask:(.*)$/
            addr = $1
            mask = $2
            @ipv4_addresses[addr] = {}
            @ipv4_addresses[addr]['mask'] = mask
          end 
        end
      rescue
        ""
      end
      return @ipv4_addresses
    end

    # returns a dict
    # {
    #   input: value
    #   output: value
    #   forward: value
    # }
    def firewall_policy
      return @firewall_policy if not @firewall_policy.nil?
      @firewall_policy = {}
      begin
        output = @session.exec!("iptables -L -n|grep 'Chain INPUT \(policy'")
        if not output.nil?
          output.chomp =~ /policy (.*)\)/
          @firewall_policy['input'] = $1
        end
        output = @session.exec!("iptables -L -n|grep 'Chain OUTPUT \(policy'")
        if not output.nil?
          output.chomp =~ /policy (.*)\)/
          @firewall_policy['output'] = $1
        end
        output = @session.exec!("iptables -L -n|grep 'Chain FORWARD \(policy'")
        if not output.nil?
          output.chomp =~ /policy (.*)\)/
          @firewall_policy['forward'] = $1
        end
      rescue
        ""
      end
      return @firewall_policy
    end

    def to_hash
      { @ip => {
          'hostname' => @hostname,
          'root_ssh_pubkeys' => @root_ssh_pubkeys,
          'routes' => @routes,
          'users' => @users,
          'startup_services' => @startup_services,
          'net_devices' => @net_devices,
          'ipv4_addresses' => @ipv4_addresses,
          'firewall_policy' => @firewall_policy,
        }
      }
    end

    class << self
      def from_yaml(yaml_file)
        hostlist = []
        File.open yaml_file do |f|
          buffer = YAML.load(f)
          buffer.each_key do |k| 
            obj = buffer[k]
            rh = RemoteHost.new(k)
            rh.hostname = obj['hostname']
            rh.root_ssh_pubkeys = obj['root_ssh_pubkeys']
            rh.routes = obj['routes']
            rh.users = obj['users']
            rh.startup_services = obj['startup_services']
            rh.net_devices = obj['net_devices']
            rh.ipv4_addresses = obj['ipv4_addresses']
            rh.firewall_policy = obj['firewall_policy']
            hostlist << rh
          end
        end
        return hostlist
      end
    end

  end #class RemoteHost
end # module


