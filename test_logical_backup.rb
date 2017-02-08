#!/usr/bin/env ruby

require 'optparse'
require 'pathname'

def colorize(text, color_code)
  "\033[#{color_code}m#{text}\033[0m"
end

def red(text)
  colorize(text, 31)
end

class LogicalBackupTest
  IMAGE = 'postgres'

  class ScriptOptions
    attr_reader :pg_version, :user, :password, :dbname, :filepath, :verbose

    def initialize(args)
      self.pg_version = 'latest'
      self.password = ''
      self.verbose = false

      OptionParser.new do |parser|
        define_options(parser)
        parser.parse!(args)
      end

      self.filepath = args.pop 
      verify_filepath
    end

    def define_options(parser)
      parser.banner = "Usage: logical_backup_test.rb [options] dump_file"
      parser.separator ""

      parser.on('-U', '--user [USER]', 'DB user. Will be created and will be db owner') do |db_user_param|
        self.user = db_user_param
      end

      parser.on('-p', '--password [PASSWORD]', 'DB password. Will be set for db user (optional).') do |db_password_param|
        self.password = db_password_param
      end

      parser.on('-d', '--dbname [NAME]', 'DB name. Should be same as in dump file') do |db_name_param|
        self.dbname = db_name_param
      end

      parser.on("-V [VERSION]", "--pg-version [VERSION]", "PostgreSQL version to perform restore on (default: latest)") do |pg_version_param|
        self.pg_version = pg_version_param
      end

      parser.on("-v", "--[no-]verbose", "Run verbosely") do |verbose_param|
        self.verbose = verbose_param
      end

      parser.on_tail("-h", "--help", "Show this message") do
        puts parser
        exit
      end
    end
  
    private

    attr_writer :pg_version, :user, :password, :dbname, :filepath, :verbose

    def verify_filepath
      unless filepath
        puts "#{red('ERROR')}: file not specified"
        exit(1)
      end
      pathname = Pathname.new(filepath)
      unless pathname.exist?
        puts "#{red('ERROR')}: file specified does not exist"
        exit(1)
      end

      if pathname.directory?
        puts "#{red('ERROR')}: path specified is directory"
        exit(1)
      end
    end
  end

  def initialize(args)
    @options = ScriptOptions.new(args)
  end

  def execute
    pull_image
    deploy_container
    on_container_ready do
      restore_db
    end
  rescue StandardError => exception
    puts "#{red('ERROR')}: #{exception}"
    exit(1)
  ensure
    remove_container
  end

  private

  attr_reader :options

  def print_out(msg)
    return unless options.verbose
    puts msg
  end

  def container_name
    "logical_restore_#{options.dbname}"
  end

  def pull_image
    image_name = "#{IMAGE}:#{options.pg_version}"
    print_out "--- Pulling #{image_name}"
    %x{ docker pull #{image_name} }
  end

  def deploy_container
    print_out '--- Deploying container'
    container_id =  %x{
      docker run \
             -d \
             -e "POSTGRES_PASSWORD=#{options.password}" \
             -e "POSTGRES_USER=#{options.user}" \
             -e "POSTGRES_DB=#{options.dbname}" \
             --name #{container_name} \
             #{IMAGE}:#{options.pg_version}
    }
    raise StandardError, "exited with #{$?.exitstatus}" unless $?.exitstatus == 0
    container_id = container_id.delete("\n")
  end

  def on_container_ready
    print_out '--- Waiting for container start'
    container_ready = false
    15.times do
      version_string =  %x{ docker exec #{container_name} psql -U #{options.user} -d #{options.dbname} -A -t -c "select version();" }
      if version_string.start_with? "PostgreSQL"
        container_ready = true
        break
      end
      sleep 1
    end
  
    raise StandardError, 'failed on wait for container ready' unless container_ready

    yield if block_given?
  end

  def restore_db
    print_out '--- Started restore'
    %x{ 
      docker exec -i #{container_name} \
        pg_restore -Fc \
                   -U #{options.user} \
                   -d #{options.dbname} \
                   --no-password \
                   --exit-on-error \
                   --verbose < #{options.filepath} 
    }
    raise StandardError, 'Failed on restore db' unless $?.exitstatus == 0
  end

  def remove_container
    %x{ docker rm -f #{container_name} }
  end
end

LogicalBackupTest.new(ARGV).execute
