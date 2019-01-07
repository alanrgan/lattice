require "./config/*"

require "yaml"

struct Config
  include YAML::Serializable

  @[YAML::Field(key: "local")]
  property local_host : Host
  @[YAML::Field(key: "known_hosts")]
  property known_hosts : Array(Host)

  def self.load(file)
    File.open(file) do |f|
      self.from_yaml(f)
    end
    # @@data = YAML.parse(ARGF)
    # @@data
  end
end