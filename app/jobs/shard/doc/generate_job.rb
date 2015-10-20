require 'open3'

class Shard::Doc::GenerateJob < ActiveJob::Base
  queue_as :default

  def perform(shard_id, sha)
    @shard = Shard.find(shard_id)
    @doc = @shard.docs.by_sha(sha)

    return unless @doc

    logger.info("Checkout to #{working_dir}")
    FileUtils.mkdir_p(working_dir)

    @repository = Rugged::Repository.clone_at(@shard.git_url, working_dir.to_s)
    @repository.checkout(@doc.sha)

    generate_document
    upload_document

    @doc.touch(:generated_at)
  rescue ActiveRecord::RecordNotFound
  ensure
    FileUtils.rm_rf(working_dir) if @doc && File.directory?(working_dir)
  end

  private

  def working_dir
    @working_dir ||= Rails.root.join('tmp', 'crystal-doc', "#{@shard.id}-#{@doc.id}-#{Time.current.to_f}")
  end

  def generate_document
    execute_pre_commands
    execute_doc_commands
    execute_post_commands
  end

  def execute_pre_commands
    shell('shards', 'install') if File.exists?(working_dir.join('shard.yml'))
  end

  def execute_doc_commands
    shell('crystal', 'doc')
  end

  def execute_post_commands
  end

  def upload_document
    Dir[working_dir.join('doc/**/*')].each do |file|
      next if File.directory?(file)

      path = file.sub(%r{^#{Regexp.escape(working_dir.to_s)}/doc/}, '')
      logger.info("Upload: #{path}")

      open(file) do |f|
        @doc.storage.put(path, f)
      end
    end
  end

  def shell(cmd, *args)
    logger.info("$ #{cmd} #{args.join(' ')}")
    Open3.popen3("#{cmd} #{args.join(' ')}", chdir: working_dir) do |input, stdout, stderr, wait|
      input.close

      stdout.each do |line|
        logger.info(line)
      end

      stderr.each do |line|
        logger.error(line)
      end

      wait.value
    end
  end
end
