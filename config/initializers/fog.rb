class Docrystal::Storage
  def self.config
    @config ||= YAML.load(ERB.new(File.read(Rails.root.join('config/fog.yml'))).result)[Rails.env].symbolize_keys
  end

  def self.fog_storage
    Fog::Storage.new(config)
  end

  def initialize(directory)
    @directory = self.class.fog_storage.directories.create(key: directory, public: true)
  end

  attr_reader :directory

  def exists?(path)
    directory.files.head(path).present?
  end

  def read(path)
    directory.files.get(path).try(:body)
  end

  def get(path)
    directory.files.get(path)
  end

  def put(path, body)
    directory.files.create(
      key: path,
      body: body,
      public: true
    )
  end
end
