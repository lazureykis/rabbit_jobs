# require 'rabbit_jobs/tasks'
# will give you the resque tasks

require 'rabbit_jobs'
require 'logger'
require 'rake'

def rails_env
  $my_rails_env ||= defined?(Rails) ? Rails.env : (ENV['RAILS_ENV'] || 'development')
end

def app_root
  $my_rails_root ||= Pathname.new(ENV['RAILS_ROOT'] || Rails.root)
end

def make_dirs
  ["log", "tmp", "tmp/pids"].each do |subdir|
    dir = app_root.join(subdir)
    Dir.mkdir(dir) unless File.directory?(dir)
  end
end

namespace :rj do
  task :environment do
    # Rails.application.eager_load!
    Rails.application.require_environment!
  end

  # MULTIPROCESS
  namespace :worker do
    desc "Start a Rabbit Jobs workers from config/rj_workers.yml"
    task :start => [:environment, :load_config] do
      make_dirs
      RJ.config.workers.each do |worker_name, worker_props|
        worker_num = 1
        worker_props['instances'].to_i.times do
          unless @do_only.count > 0 && !@do_only.include?("#{worker_name}-#{worker_num}")
            queues = (worker_props['queue'] || worker_props['queues'] || "").split(' ')

            worker = RJ::Worker.new(*queues)
            worker.background = true
            worker.process_name = "rj_worker #{worker_name}##{worker_num} #{rails_env} [#{queues.join(',')}]"
            worker.pidfile = app_root.join("tmp/pids/rj_worker_#{rails_env}_#{worker_name}_#{worker_num}.pid")
            RJ.logger = ::Logger.new(app_root.join("log/rj_worker_#{rails_env}_#{worker_name}_#{worker_num}.log"), 'daily')
            # RJ.logger.level = ENV['VERBOSE'] ? Logger::INFO : Logger::WARN
            puts "Starting #{worker_name}##{worker_num}"

            # завершаем копию процесса, если воркер уже отработал
            exit! if worker.work
          end
          worker_num += 1
        end
      end
    end

    task :stop => :load_config do
      # получаем идентификаторы процессов
      pids = {}
      errors = []

      RJ.config.workers.each do |worker_name, worker_props|
        worker_num = 1
        worker_props['instances'].to_i.times do
          unless (@do_only.count > 0) && !@do_only.include?("#{worker_name}-#{worker_num}")
            pidfile = app_root.join("tmp/pids/rj_worker_#{rails_env}_#{worker_name}_#{worker_num}.pid")

            unless File.exists?(pidfile)
              msg = "Pidfile not found: #{pidfile}"
              errors << msg
              $stderr.puts msg
            else
              pid = open(pidfile).read.to_i
              pids[pid] = pidfile
              queues = (worker_props['queue'] || worker_props['queues'] || "").split(' ')
              puts "Stopping rj_worker #{worker_name}##{worker_num} #{rails_env} [#{queues.join(',')}]"
            end
          end
          worker_num += 1
        end
      end

      # пытаемся их убить
      killed_pids = []
      pids.each do |pid, pidfile|
        begin
          puts "try killing ##{pid}"
          Process.kill("TERM", pid)
        rescue => e
          errors << "Not found process: #{pid} from #{pidfile}"
          $stderr.puts errors.last
          $stderr.puts "Removing pidfile ..."
          File.delete(pidfile) if File.exist?(pidfile)
        end
      end

      while killed_pids.count != pids.keys.count
        pids.each_key do |pid|
          begin
            Process.kill(0, pid)
            stopped = false
            break
          rescue
            killed_pids.push(pid) unless killed_pids.include?(pid)
          end
        end
        print '.'
        sleep 1
      end

      exit(1) if not errors.empty?

      puts "\nrj_worker stopped."
      exit(0)
    end

    task :status => :load_config do

      errors ||= 0

      RJ.config.workers.each do |worker_name, worker_props|
        worker_num = 1
        worker_props['instances'].to_i.times do
          pidfile = app_root.join("tmp/pids/rj_worker_#{rails_env}_#{worker_name}_#{worker_num}.pid")

          unless File.exists?(pidfile)
            puts "Pidfile not found: #{pidfile}"
            errors += 1
          else
            pid = open(pidfile).read.to_i
            begin
              raise "must return 1" unless Process.kill(0, pid) == 1
            rescue
              puts "Pidfile found but process not respond: #{pidfile}\r\nRemoving pidfile."
              File.delete(pidfile) if File.exist?(pidfile)
              errors += 1
            end
          end
          worker_num += 1
        end
      end

      puts "ok" if errors == 0
      exit errors
    end

    task :load_config do
      @do_only = ENV["WORKERS"] ? ENV["WORKERS"].strip.split : []
      @do_only.each do |worker|
        worker_name, worker_num = worker.split('-')
        unless RJ.config.workers.keys.include?(worker_name) && RJ.config.workers[worker_name][:instances].to_i >= worker_num.to_i
          raise "Worker #{worker} not found."
        end
      end
    end
  end

  namespace :scheduler do
    task :start do
      make_dirs

      scheduler = RabbitJobs::Scheduler.new

      scheduler.background = true
      scheduler.pidfile = app_root.join('tmp/pids/rj_scheduler.pid')
      RJ.logger = ::Logger.new(app_root.join('log/rj_scheduler.log'), 'daily')
      # RJ.logger.level = ENV['VERBOSE'] ? Logger::INFO : Logger::WARN

      scheduler.work
      puts "rj_scheduler started."
    end

    task :stop do
      pidfile = app_root.join('tmp/pids/rj_scheduler.pid')

      unless File.exists?(pidfile)
        msg = "Pidfile not found: #{pidfile}"
        $stderr.puts msg
        exit(1)
      else
        pid = open(pidfile).read.to_i
        begin
          Process.kill("TERM", pid)
        rescue => e
          $stderr.puts "Not found process: #{pid} from #{pidfile}"
          $stderr.puts "Removing pidfile ..."
          File.delete(pidfile) if File.exist?(pidfile)
          exit(1)
        end

        while true
          begin
            Process.kill(0, pid)
            sleep 0.1
          rescue
            puts "rj_scheduler[##{pid}] stopped."
            exit(0)
          end
        end
      end
    end

    task :status do
      pidfile = app_root.join('tmp/pids/rj_scheduler.pid')

      unless File.exists?(pidfile)
        puts "Pidfile not found: #{pidfile}"
        exit(1)
      else
        pid = open(pidfile).read.to_i
        begin
          raise "must return 1" unless Process.kill(0, pid) == 1
          puts "ok"
        rescue
          puts "Pidfile found but process not respond: #{pidfile}"
          puts "Removing pidfile."
          File.delete(pidfile) if File.exist?(pidfile)
          exit(1)
        end
      end
      exit(0)
    end
  end

  # desc "Start a Rabbit Jobs scheduler"
end