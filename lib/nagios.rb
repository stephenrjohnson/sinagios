class NonExistentCmdFile < Exception; end
class NonWritableCmdFile < Exception; end

class Nagios
  # FIXME: Harvest the cmd_file location from actual Nagios config somehow
  def initialize(cmd_file = '/var/spool/nagios/cmd/nagios.cmd')
    @cmd_file = cmd_file
    unless File.exist?(@cmd_file) then raise NonExistentCmdFile end
    unless File.writable?(@cmd_file) then raise NonWritableCmdFile end
  end

  def downtimes (statusfile='/var/log/nagios/status.dat')
    f = File.open(statusfile)
    state = :outsideblock
    host = nil
    downtimes = {}
    f.readlines().each do |line|
      if line =~ /^(service|host)downtime \{/ and state == :outsideblock
        state = $~[1].to_sym
      elsif line =~ /host_name=(.*)/ and [:host, :service].include?(state)
        host = $~[1]
        downtimes[host] ||= {:host => [], :service => []}
      elsif line =~ /downtime_id=(.*)/ and [:host, :service].include?(state)
        downtimes[host][state] << $~[1]
      elsif line =~ /\}/ and [:host, :service].include?(state)
        state = :outsideblock
      end
    end
    f.close
    return downtimes
  end

  def delete_downtimes(host, downtimes)
    [[:host,:host],[:service,:svc]].each do |input_type,output_type|

      downtimes[host][input_type].each do |id|
        command = "[#{Time.now.utc.to_i}] DEL_#{output_type.to_s.upcase}_DOWNTIME;#{id}"
        File.open(@cmd_file, 'w') do |c|
          c.puts(command)
        end
      end
    end
    return "All downtime deleted for #{host}"
  end
end
