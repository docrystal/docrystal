class Docrystal::Storage
  def self.config
    @config ||= YAML.load(ERB.new(File.read(Rails.root.join('config/fog.yml'))).result)[Rails.env].symbolize_keys
  end

  def self.fog_storage
    Fog::Storage.new(config.except(:directory))
  end

  def self.fog_directory
    dir = fog_storage.directories.get(config[:directory])
    dir = fog_storage.directories.create(key: config[:directory], public: true) unless dir
    dir
  end

  def initialize(prefix)
    @prefix = Pathname.new(prefix)
    @directory = self.class.fog_directory
  end

  attr_reader :directory

  def exists?(path)
    directory.files.head(@prefix.join(path)).present?
  end

  def read(path)
    directory.files.get(@prefix.join(path)).try(:body)
  end

  def get(path)
    directory.files.get(@prefix.join(path))
  end

  def put(path, body)
    directory.files.create(
      key: @prefix.join(path),
      body: body,
      public: true
    )
  end
end
