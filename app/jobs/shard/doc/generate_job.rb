require 'open3'
require 'thwait'

class Shard::Doc::GenerateJob < ActiveJob::Base
  class ShellError < StandardError
  end

  ALLOWED_ENVS = %w(
    PATH
    RAILS_ENV
    RACK_ENV
    BUNDLE_BIN_PATH
    BUNDLE_GEMFILE
    TMPDIR
    LANG
    HOME
    DISPLAY
  )

  queue_as :default

  before_perform do
    RequestStore.clear!
  end

  def perform(doc_id)
    @doc = Shard::Doc.find(doc_id)

    return unless @doc

    sleep 2

    FileUtils.mkdir_p(working_dir)

    log("Create container for #{@doc.shard.full_name}")
    container.start({ 'Binds' => ["#{working_dir}:#{container_doc_path}"] })

    log("Clone #{@doc.shard.full_name}")
    shell('git', 'clone', @doc.shard.git_url, container_working_dir)
    shell('git', 'checkout', @doc.sha, chdir: container_working_dir)

    generate_document
    upload_document

    @doc.touch(:generated_at)
    pusher_threads.join(Thread.new { Pusher.trigger(@doc.log_pusher_key, 'success', at: Time.current) })
  rescue => e
    if @doc
      @doc.update(error: e.class, error_description: e.message)
      pusher_threads.join(Thread.new { Pusher.trigger(@doc.log_pusher_key, 'fail', at: Time.current) })
    end
  ensure
    pusher_threads.all_waits

    if @doc
      container.kill
      container.wait
      container.delete
      FileUtils.rm_rf(working_dir) if File.directory?(working_dir)
      Docrystal.redis.del(@doc.log_redis_key)
    end
  end

  private

  def working_dir
    @working_dir ||= Rails.root.join(
      'tmp', 'crystal-doc', Digest::SHA1.hexdigest("#{@doc.shard_id}-#{@doc.id}-#{Time.current.to_f}")
    )
  end

  def container
    @container ||= Docker::Container.create(
      'Image' => 'docrystal/crystal:v0.9.0',
      'Cmd' => ['bash', '-c', 'while : ; do sleep 1; done'],
      'Tty' => false,
      'OpenStdin' => false,
      'Volumes' => {
        container_doc_path => {}
      }
    )
  end

  def container_working_dir
    @container_working_dir ||= Pathname.new('/tmp/src').join(@doc.shard.full_name)
  end

  def container_doc_path
    '/tmp/artifacts'
  end

  def generate_document
    execute_pre_commands
    execute_doc_commands
    execute_post_commands
  end

  def execute_pre_commands
    if File.exists?(working_dir.join('shard.yml'))
      shell('shards', 'install', chdir: container_working_dir)
    else
      shell('crystal', 'deps', chdir: container_working_dir) if File.exists?(working_dir.join('Projectfile'))
    end
  end

  def execute_doc_commands
    if @doc.shard.full_name == 'github.com/manastech/crystal'
      shell('make', 'doc', chdir: container_working_dir)
    else
      shell('crystal', 'doc', chdir: container_working_dir)
    end
  end

  def execute_post_commands
    shell('cp', '-r', container_working_dir.join('doc'), container_doc_path)
    shell('chmod', '-R', '777', container_doc_path)
  end

  def upload_document
    log("\n")

    files = Dir[working_dir.join('doc/**/*')].select { |path| !File.directory?(path) }
    files.map! { |file| file.sub(%r{^#{Regexp.escape(working_dir.to_s)}/doc/}, '') }

    max_filename_length = files.map(&:length).max

    Parallel.each(files, in_threads: 16) do |path|
      log("Upload: #{path.rjust(max_filename_length)}\r", plain: false)

      open(working_dir.join('doc', path)) do |f|
        @doc.storage.put(path, f)
      end
    end
    log("\nAll File uploaded")
  end

  def shell(cmd, *args, chdir: nil)
    log("$ #{cmd} #{args.join(' ')}")

    cmd_log = ["$ #{cmd} #{args.join(' ')}\n"]

    command = ['bash', '-c']
    if chdir
      command += ["cd #{chdir} && #{cmd} #{args.join(' ')}"]
    else
      command += ["#{cmd} #{args.join(' ')}"]
    end

    retval = container.exec(command) do |stream, chunk|
      log(chunk, plain: false)
      cmd_log << chunk.to_s
    end

    fail ShellError, cmd_log.join("") unless retval.last == 0
  end

  def log(msg, plain: true)
    return if msg.nil? || msg.empty?

    logger.info(msg.strip)

    if @doc
      msg += "\n" if plain && msg[-1] != "\n"
      terminal << msg
      pusher_threads.join(Thread.new(Terminal.render(terminal)) { |msg| Pusher.trigger(@doc.log_pusher_key, 'update', terminal: msg) })
      Docrystal.redis.append(@doc.log_redis_key, msg)
    end
  end

  def pusher_threads
    @pusher_threads ||= ThreadsWait.new
  end

  def terminal
    @terminal ||= ""
  end

  def environments
    @environments ||= ENV.to_hash.tap do |env|
      (env.keys - ALLOWED_ENVS).each do |key|
        env[key] = '******'
      end
    end
  end
end
