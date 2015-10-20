require 'open3'
require 'thwait'

class Shard::Doc::GenerateJob < ActiveJob::Base
  class ShellError < StandardError
  end

  queue_as :default

  before_perform do
    RequestStore.clear!
  end

  def perform(doc_id)
    @doc = Shard::Doc.find(doc_id)

    return unless @doc

    sleep 2

    log("Clone #{@doc.shard.full_name}")
    FileUtils.mkdir_p(working_dir)

    progress_lambda = lambda do |msg|
      log(msg, plain: false)
    end

    @repository = Rugged::Repository.clone_at(@doc.shard.git_url, working_dir.to_s, progress: progress_lambda)
    @repository.checkout_tree(@doc.sha, strategy: :force)
    log("Checkout : #{@doc.sha}")

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

  def generate_document
    execute_pre_commands
    execute_doc_commands
    execute_post_commands
  end

  def execute_pre_commands
    if File.exists?(working_dir.join('shard.yml'))
      shell('shards', 'install')
    else
      shell('crystal', 'deps') if File.exists?(working_dir.join('Projectfile'))
    end
  end

  def execute_doc_commands
    if @doc.shard.full_name == 'github.com/manastech/crystal'
      shell('make', 'doc')
    else
      shell('crystal', 'doc')
    end
  end

  def execute_post_commands
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

  def shell(cmd, *args)
    log("$ #{cmd} #{args.join(' ')}")

    cmd_log = ["$ #{cmd} #{args.join(' ')}\n"]

    retval = Open3.popen3("#{cmd} #{args.join(' ')}", chdir: working_dir) do |input, stdout, stderr, wait|
      input.close

      stdout.each do |line|
        log(line, plain: false)
        cmd_log << line
      end

      stderr.each do |line|
        logger.error(line)
        cmd_log << line
      end

      wait.value
    end

    fail ShellError, cmd_log.join("") unless retval.success?
  end

  def log(msg, plain: true)
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
end
