module MechFarmer
require 'rubygems'
require 'net/ssh'
require 'net/ping'
require 'timeout'
require 'socket'
require 'ip'
require 'ftools'
require 'yaml'

  class Maintainer

    attr_accessor :teams, :ssh_pubkeys, :full_name, :nickname, :email

    def initialize
      @teams = []
      @ssh_pubkeys = []
      @full_name = nil
      @nickname = nil
      @email = nil
    end

    def self.from_yaml(file)
      list = []
      File.open file do |f|
        buffer = YAML.load(f)
        buffer.each_key do |k| 
          obj = buffer[k]
          m = Maintainer.new
          m.full_name = k
          m.teams = obj['teams']
          m.ssh_pubkeys = obj['ssh_pubkeys']
          m.nickname = obj['nickname']
          m.email = obj['email']
          list << m
        end
      end
      return list
    end
    
    def to_hash
      {
        @full_name => {
          'email' => @email,
          'teams' => @teams,
          'nickname' => @nickname,
          'ssh_pubkeys' => @ssh_pubkeys
        }
      }
    end


    def to_s
      "Full Name:             #{@full_name}\n" +
      "Nickname:              #{@nickname}\n" +
      "Teams:                 #{@teams.join(',')}\n" +
      "Email:                 #{@email}\n" +
      "SSH Publibc Keys:      #{@ssh_pubkeys.size}"
    end

  end

  class Inventory

    attr_accessor :dbfile

    def initialize
      @items = []
      @dbfile = 'inventory.yaml'
    end
    
    def add_item(remote_host)
      if @items.find { |i| i.hostname == remote_host.hostname }.nil?
        @items << remote_host
        return true
      end
      return false
    end

    def delete(hostname)
      found = @items.find { |i| i.hostname == hostname }
      @items.delete found
    end

    def self.load_from_file(file)
      items = RemoteHost.from_yaml(file)
      inventory = Inventory.new
      inventory.dbfile = file
      inventory.instance_eval "@items = items"
      return inventory
    end

    def size
      @items.size
    end

    def each
      @items.each do |i| yield i end
    end

    def write(backup=true)
      if backup and File.exist? @dbfile
        bf = "#{@dbfile}.bak.#{Time.now.strftime('%Y%m%d-%H:%M:%S')}"
        File.copy(@dbfile, bf)
      end

      File.open(@dbfile, 'w') do |f|
        inventory_object = {}
        @items.each do |item|
          hash = item.to_hash
          inventory_object[hash.keys[0]] = hash.values[0]
        end
        f.puts inventory_object.to_yaml
      end
    end

  end

  class RemoteHost

    attr_reader :session, :farmed, :farming_address
    attr_writer :hostname, :root_ssh_pubkeys, :routes, :users
    attr_writer :startup_services, :net_devices, :ipv4_addresses
    attr_writer :firewall_policy

    def initialize(farming_address)
      @farming_address = farming_address
      @hostname = nil
      @root_ssh_pubkeys = nil
      @routes = nil
      @users = nil
      @startup_services = nil
      @net_devices = nil
      @ipv4_addresses = nil
      @firewall_policy = nil
      @farmed = false
    end

    def run_command!(command)
      @session = Net::SSH.start(@farming_address, 'root', :timeout => 2)
      @session.exec! command
    end

    def farm
      begin
        timeout(0.1) do
          t = TCPSocket.new(@farming_address, '22')
        end
      rescue Exception
        return false
      end
      begin
        @session = Net::SSH.start(@farming_address, 'root', :timeout => 1)
      rescue Exception
        @session = nil
        return false
      end
      hostname
      root_ssh_pubkeys
      routes
      users
      startup_services
      net_devices
      ipv4_addresses
      firewall_policy
      @session.close
      @session = nil
      @farmed = true
      return @farmed
    end

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

    def alive?
      return Net::PingExternal.new(@farming_address).ping
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
        output = @session.exec!("ip address |grep inet|grep -v inet6|grep -v peer")
        if not output.nil?
          output.each_line do |l|
            cidr_string = l.split[1].strip
            addr = cidr_string.split('/')[0]
            cidr = IP::CIDR.new(cidr_string)
            @ipv4_addresses[addr] = {}
            @ipv4_addresses[addr]['mask'] = cidr.long_netmask.ip_address
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
      { @hostname => {
          'root_ssh_pubkeys' => @root_ssh_pubkeys,
          'routes' => @routes,
          'users' => @users,
          'startup_services' => @startup_services,
          'net_devices' => @net_devices,
          'ipv4_addresses' => @ipv4_addresses,
          'firewall_policy' => @firewall_policy,
          'farming_address' => @farming_address
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
            rh.hostname = k
            rh.root_ssh_pubkeys = obj['root_ssh_pubkeys']
            rh.routes = obj['routes']
            rh.users = obj['users']
            rh.startup_services = obj['startup_services']
            rh.net_devices = obj['net_devices']
            rh.ipv4_addresses = obj['ipv4_addresses']
            rh.firewall_policy = obj['firewall_policy']
            rh.instance_eval "@farming_address = '#{obj['farming_address']}'"
            hostlist << rh
          end
        end
        return hostlist
      end
    end

  end #class RemoteHost
end # module


