require "language_pack"
require "language_pack/rails2"

class LanguagePack::Rails3 < LanguagePack::Rails2
  NODE_JS_BINARY_PATH = 'node-0.4.7/node'

  def self.use?
    super &&
      File.exists?("config/application.rb") &&
      File.read("config/application.rb") =~ /Rails::Application/
  end

  def name
    "Ruby/Rails"
  end

  def default_process_types
    web_process = gem_is_bundled?("thin") ?
                    "bundle exec thin start -R config.ru -e $RAILS_ENV -p $PORT" :
                    "bundle exec rails server -p $PORT"

    super.merge({
      "web" => web_process,
      "console" => "bundle exec rails console"
    })
  end

  def compile
    super
    allow_git { setup_asset_pipeline }
  end

private

  def plugins
    super.concat(%w( rails3_serve_static_assets )).uniq
  end

  def binaries
    node = gem_is_bundled?('execjs') ? [NODE_JS_BINARY_PATH] : []
    super + node
  end

  def setup_asset_pipeline
    if rake_task_defined?("assets:precompile")
      topic("Preparing app for Rails asset pipeline")
      if File.exists?("public/assets/manifest.yml")
        puts "Detected manifest.yml, assuming assets were compiled locally"
      else
        ENV["DATABASE_URL"] ||= begin
          # need to use a dummy DATABASE_URL here, so rails can load the environment
          scheme =
            if gem_is_bundled?("pg")
              "postgres"
            elsif gem_is_bundled?("mysql")
              "mysql"
            elsif gem_is_bundled?("mysql2")
              "mysql2"
            elsif gem_is_bundled?("sqlite3") || gem_is_bundled?("sqlite3-ruby")
              "sqlite3"
            end
          "#{scheme}://user:pass@127.0.0.1/dbname"
        end

        ENV["RAILS_GROUPS"] ||= "assets"
        ENV["RAILS_ENV"]    ||= "production"

        puts "Running: rake assets:precompile"
        rake_output = ""
        rake_output << run("env PATH=$PATH:bin bundle exec rake assets:precompile 2>&1")
        puts rake_output
        unless $?.success?
          puts "Precompiling assets failed, enabling runtime asset compilation"
          install_plugin("rails31_enable_runtime_asset_compilation")
          puts "Please see this article for troubleshooting help:"
          puts "http://devcenter.heroku.com/articles/rails31_heroku_cedar#troubleshooting"
          # uninstall_binary(NODE_JS_BINARY_PATH)
        end
      end
    end
  end

end