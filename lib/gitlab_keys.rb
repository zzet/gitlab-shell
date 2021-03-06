require 'tempfile'
require 'timeout'

require_relative 'gitlab_config'
require_relative 'gitlab_logger'

class GitlabKeys
  attr_accessor :auth_file, :key

  def initialize
    @command = ARGV.shift
    @key_id = ARGV.shift
    @key = ARGV.shift

    @config = GitlabConfig.new
    @auth_file = @config.auth_file
  end

  def exec
    case @command
    when 'add-key'; add_key
    when 'batch-add-keys'; batch_add_keys
    when 'rm-key';  rm_key
    when 'clear';  clear
    else
      $logger.warn "Attempt to execute invalid gitlab-keys command #{@command.inspect}."
      puts 'not allowed'
      false
    end
  end

  protected

  def add_key
    lock do
      $logger.info "Adding key #{@key_id} => #{@key.inspect}"
      auth_line = key_line(@key_id, @key)
      open(auth_file, 'a') { |file| file.puts(auth_line) }
    end
    true
  end

  def batch_add_keys
    lock do
      open(auth_file, 'a') do |file|
        stdin.each_line do |input|
          tokens = input.strip.split("\t")
          abort("#{$0}: invalid input #{input.inspect}") unless tokens.count == 2
          key_id, public_key = tokens
          $logger.info "Adding key #{key_id} => #{public_key.inspect}"
          file.puts(key_line(key_id, public_key))
        end
      end
    end
    true
  end

  def stdin
    $stdin
  end

  def key_line(key_id, public_key)
    "command=\"#{@config.gitlab_shell_path}/bin/gitlab-shell #{key_id}\",no-port-forwarding,no-X11-forwarding,no-agent-forwarding,no-pty #{public_key}"
  end

  def rm_key
    lock do
      $logger.info "Removing key #{@key_id}"
      Tempfile.open('authorized_keys') do |temp|
        open(auth_file, 'r+') do |current|
          current.each do |line|
            temp.puts(line) unless line.include?("/bin/gitlab-shell #{@key_id}\"")
          end
        end
        temp.close
        FileUtils.cp(temp.path, auth_file)
      end
    end
    true
  end

  def clear
    open(auth_file, 'w') { |file| file.puts '# Managed by gitlab-shell' }
    true
  end


  def lock(timeout = 10)
    File.open(lock_file, "w+") do |f|
      begin
        f.flock File::LOCK_EX
        Timeout::timeout(timeout) { yield }
      ensure
        f.flock File::LOCK_UN
      end
    end
  end

  def lock_file
    @lock_file ||= auth_file + '.lock'
  end
end
