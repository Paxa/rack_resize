require "rack_resize"
require "rails"

module MyGem
  class Railtie < Rails::Railtie
    initializer "rack_resize.auto_register_itself" do |app|
      app.config.middleware.insert_before 0, RackResize::RackApp
    end
  end
end
