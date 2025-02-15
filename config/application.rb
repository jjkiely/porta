require_relative 'boot'

require 'rails/all'

ActiveSupport.on_load(:active_record) do
  # Some rails tasks like db:create may load database before environment
  if $environment_loaded && !$last_initializer_loaded
    warning = "WARNING: ActiveRecord loading before initializers completed. Configuration set in initializers may not be effective:#{caller.map { |l| "\n  #{l}"}.join}"
    STDERR.puts warning rescue nil # avoid failing if write fails
  end
end

# If you precompile assets before deploying to production, use this line
Bundler.require(*Rails.groups(:oracle, assets: %w[development production test]))
# If you want your assets lazily compiled in production, use this line
# Bundler.require(:default, :assets, Rails.env)

ActiveSupport::XmlMini.backend = 'Nokogiri'

module System

  module AssociationExtension
    def self.included(base)
      base.define_singleton_method(:to_proc) do
        ->(_) { include base }
      end
    end
  end

  mattr_accessor :redis

  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    # we do here instead of using initializers because of a Rails 5.1 vs
    # MySQL bug where `rake db:reset` causes ActiveRecord to be loaded
    # before initializers and causes configuration not to be respected.
    # This is fixed in Rails 5.2
    config.load_defaults 5.1
    config.active_record.belongs_to_required_by_default = false
    config.active_record.include_root_in_json = true
    # Make `form_with` generate non-remote forms. Defaults true in Rails 5.1 to 6.0

    # Applying the patch for CVE-2022-32224 broke YAML deserialization because some classes are disallowed in the serialized YAML
    # NOTE: Symbol was later added to enabled classes by default, see https://github.com/rails/rails/pull/45584,
    # it was added to Rails 6.0.6, 6.1.7, 7.0.4
    config.active_record.yaml_column_permitted_classes = [Symbol, Time, Date, BigDecimal, OpenStruct,
                                                          ActionController::Parameters,
                                                          ActiveSupport::TimeWithZone,
                                                          ActiveSupport::TimeZone,
                                                          ActiveSupport::HashWithIndifferentAccess]

    config.action_view.form_with_generates_remote_forms = false

    # Make Ruby preserve the timezone of the receiver when calling `to_time`.
    config.active_support.to_time_preserves_timezone = false
    # Use a modern approved hashing function
    # config.active_support.hash_digest_class = OpenSSL::Digest::SHA256
    ActiveSupport::Digest.hash_digest_class = OpenSSL::Digest::SHA256 # option above should work with Rails 6.x


    # The old config_for gem returns HashWithIndifferentAccess
    # https://github.com/3scale/config_for/blob/master/lib/config_for/config.rb#L16
    def config_for(*args)
      config = super
      config.is_a?(Hash) ? config.with_indifferent_access : config
    end

    config.active_job.queue_adapter = :sidekiq

    def simple_try_config_for(*args)
      config_for(*args)
    rescue => exception # rubocop:disable Style/RescueStandardError
      warn "[Warning][ConfigFor] Failed to load config with: #{exception}" if $VERBOSE
      nil
    end

    def try_config_for(*args)
      simple_try_config_for(*args)&.symbolize_keys
    end

    config.before_eager_load do
      require 'three_scale'
    end

    config.logger = ActiveSupport::TaggedLogging.new(ActiveSupport::Logger.new(STDOUT)) if ENV['RAILS_LOG_TO_STDOUT'].present?

    config.active_record.whitelist_attributes = false

    config.boot_time = Time.now

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Include developer_portal into the autoload and eager load path
    config.autoload_paths += [Rails.root.join('lib', 'developer_portal', 'app'), Rails.root.join('lib', 'developer_portal', 'lib')]
    config.eager_load_paths += [Rails.root.join('lib', 'developer_portal', 'app'), Rails.root.join('lib', 'developer_portal', 'lib')]

    config.eager_load = true
    config.enable_dependency_loading = false

    # Only load the plugins named here, in the order given (default is alphabetical).
    # :all can be used as a placeholder for all plugins not explicitly named.
    # config.plugins = [ :exception_notification, :ssl_requirement, :all ]

    # Activate observers that should always be running.
    config.active_record.observers = :account_observer,
                                     :message_observer,
                                     :billing_observer,
                                     :post_observer,
                                     :user_observer,
                                     :billing_strategy_observer,
                                     :provider_plan_change_observer,
                                     :plan_observer

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de

    if (expansions = config.action_view.javascript_expansions)
      expansions[:defaults] = %w[]
    end

    config.assets.paths << Rails.root.join('assets')
    config.assets.paths << Rails.root.join("lib", "liquid", "template", "buyer_side")
    config.assets.paths << Rails.root.join("vendor", "assets", "images")

    config.assets.enabled = true

    config.assets.precompile = []
    config.assets.precompile << ->(filename, _path) do
      basename = File.basename(filename)

      extname = File.extname(basename)

      # skip files that start with underscore, do not have extension or are sourcemap
      extname.present? && !extname.in?(%w[.map .LICENSE .es6]) && !basename.start_with?('_')
    end
    config.assets.precompile += %w[
      font-awesome.css
      provider/signup_v2.js
      provider/signup_form.js
      provider/layout/provider.js
    ]

    config.assets.compile = false
    config.assets.digest = true
    config.assets.initialize_on_precompile = false

    config.assets.version = '1437647386' # unix timestamp

    config.public_file_server.enabled = false

    # We don't want Rack::Cache to be used
    config.action_dispatch.rack_cache = false

    args = config_for(:cache_store)
    store_type = args.shift
    options = args.extract_options!
    servers = args.flat_map { |arg| arg.split(',') }
    config.cache_store = [store_type, servers, options]

    # Configure the default encoding used in templates for Ruby 1.9.
    config.encoding = "utf-8"

    config.web_hooks = ActiveSupport::OrderedOptions.new
    config.web_hooks.merge!(config_for(:web_hooks).symbolize_keys)

    config.liquid = ActiveSupport::OrderedOptions.new
    config.liquid.resolver_caching = false

    config.representer.default_url_options = { protocol: 'https' }

    config.zync = ActiveSupport::InheritableOptions.new(try_config_for(:zync))

    config.three_scale = ActiveSupport::OrderedOptions.new
    config.three_scale.core = ActiveSupport::OrderedOptions.new

    config.three_scale.rolling_updates = ActiveSupport::OrderedOptions.new
    config.three_scale.email_sanitizer = ActiveSupport::OrderedOptions.new
    config.three_scale.sandbox_proxy = ActiveSupport::OrderedOptions.new
    config.three_scale.sandbox_proxy.merge!(config_for(:sandbox_proxy).symbolize_keys)

    config.three_scale.tracking = ActiveSupport::OrderedOptions.new
    config.three_scale.core.merge!(config_for(:core).symbolize_keys)

    config.three_scale.segment = ActiveSupport::OrderedOptions.new
    config.three_scale.segment.merge!(config_for(:segment).symbolize_keys)

    config.three_scale.redhat_customer_portal = ActiveSupport::OrderedOptions.new
    config.three_scale.redhat_customer_portal.enabled = false
    config.three_scale.redhat_customer_portal.merge!(try_config_for(:redhat_customer_portal) || {})

    config.three_scale.rolling_updates.features = try_config_for(:rolling_updates).deep_merge(try_config_for(:"extra-rolling_updates") || {})

    config.three_scale.service_discovery = ActiveSupport::OrderedOptions.new
    config.three_scale.service_discovery.enabled = false
    config.three_scale.service_discovery.merge!(try_config_for(:service_discovery) || {})

    config.three_scale.plan_rules = ActiveSupport::OrderedOptions.new
    config.three_scale.plan_rules.merge!(try_config_for(:plan_rules) || {})

    config.three_scale.currencies = ActiveSupport::OrderedOptions.new
    config.three_scale.currencies.merge!(try_config_for(:currencies) || {})

    config.three_scale.features = ActiveSupport::OrderedOptions.new
    config.three_scale.features.merge!(try_config_for(:features) || {})

    config.domain_substitution = ActiveSupport::OrderedOptions.new
    config.domain_substitution.merge!(try_config_for(:domain_substitution) || {})

    config.three_scale.cors = ActiveSupport::OrderedOptions.new
    config.three_scale.cors.enabled = false
    config.three_scale.cors.merge!(try_config_for(:cors) || {})

    three_scale = config_for(:settings).symbolize_keys
    three_scale[:error_reporting_stages] = three_scale[:error_reporting_stages].to_s.split(/\W+/)

    payment_settings = three_scale.extract!(:active_merchant_mode, :active_merchant_logging, :billing_canaries)
    config.three_scale.payments = ActiveSupport::OrderedOptions.new
    config.three_scale.payments.enabled = false
    config.three_scale.payments.merge!(payment_settings)
    config.three_scale.payments.merge!(try_config_for(:payments) || {})
    config.three_scale.payments.active_merchant_mode ||= Rails.env.production? ? :production : :test

    email_sanitizer_configs = (three_scale.delete(:email_sanitizer) || {}).symbolize_keys
    config.three_scale.email_sanitizer.merge!(email_sanitizer_configs)

    config.three_scale.merge!(three_scale.slice!(:force_ssl, :access_code))
    three_scale.each do |key, val|
      config.public_send("#{key}=", val)
    end

    config.action_mailer.default_url_options = { protocol: 'https' }
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.smtp_settings = smtp_config = (try_config_for(:smtp) || {})
    config.action_mailer.raise_delivery_errors = smtp_config[:address].present?

    config.cms_files_path = ':url_root/:date_partition/:basename-:random_secret.:extension'

    require 'three_scale/deprecation'
    require 'three_scale/domain_substitution'
    require 'three_scale/middleware/multitenant'
    require 'three_scale/middleware/cors'

    config.middleware.use ThreeScale::Middleware::Multitenant, :tenant_id
    config.middleware.insert_before Rack::Runtime, Rack::UTF8Sanitizer
    config.middleware.insert_before Rack::Runtime, Rack::XServedBy # we can pass hashed hostname as parameter
    config.middleware.insert_before 0, ThreeScale::Middleware::Cors if config.three_scale.cors.enabled

    config.unicorn = ActiveSupport::OrderedOptions[after_fork: []]

    config.action_dispatch.cookies_serializer = :hybrid

    initializer :load_configs, before: :load_config_initializers do
      config.backend_client = { max_tries: 5 }.merge(config_for(:backend).symbolize_keys)
      config.redis = config.sidekiq = config_for(:redis)
      config.s3 = config_for(:amazon_s3)
      config.three_scale.oauth2 = config_for(:oauth2)
    end

    initializer :log_formatter, after: :initialize_logger do
      config.log_formatter = System::ErrorReporting::LogFormatter.new
      (config.logger || Rails.logger).formatter = config.log_formatter
    end

    config.paperclip_defaults = {
      storage: :s3,
      s3_credentials: ->(*) { CMS::S3.credentials },
      bucket: ->(*) { CMS::S3.bucket },
      s3_protocol: ->(*) { CMS::S3.protocol },
      s3_permissions: 'private',
      s3_headers: { "checksum-algorithm" => "SHA256" },
      s3_region: ->(*) { CMS::S3.region },
      s3_host_name: ->(*) { CMS::S3.hostname },
      url: ':storage_root/:class/:id/:attachment/:style/:basename.:extension',
      path: ':rails_root/public/system/:url'
    }.merge(try_config_for(:paperclip) || {})

    initializer :paperclip_defaults, after: :load_config_initializers do
      Paperclip::Attachment.default_options.merge!(s3_options: CMS::S3.options) # Paperclip does not accept s3_options set as a Proc
    end

    config.before_initialize do
      require 'three_scale'
    end

    config.after_initialize do
      ThreeScale.validate_settings!
      require 'system/redis_pool'
      redis_config = ThreeScale::RedisConfig.new(config.redis)
      System.redis = System::RedisPool.new(redis_config.config)
    end

    config.assets.quiet = true

    console do
      if sandbox?
        puts <<~WARNING.strip_heredoc
          \e[5;37;41m
          YOU ARE USING SANDBOX MODE. DO NOT MODIFY RECORDS! THIS IS DANGEROUS AS IT WILL LOCK TABLES!
          See https://github.com/3scale/system/issues/6616
          \e[0m
        WARNING
      end
    end

    # Fixes 'DEPRECATION WARNING: Time columns will become time zone aware in Rails 5.1' keeping backwards compatibility
    config.active_record.time_zone_aware_types = [:datetime]
  end
end

# FIXME: we should cleanup our state machines and remove this
StateMachines::Machine.ignore_method_conflicts = true
