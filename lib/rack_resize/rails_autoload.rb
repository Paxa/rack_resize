require 'rack_resize'

# Rails.application.config.to_prepare do
#   require 'rack_resize'
#   Rails.application.config.middleware.insert_before 0, RackResize::RackApp
# end


require "rails"

module MyGem
  class Railtie < Rails::Railtie
    initializer "rack_resize.auto_register_itself" do |app|
      # Insert your middleware into the stack
      # app.config.middleware.use MyGem::MyMiddleware
      app.config.middleware.insert_before 0, RackResize::RackApp
    end
  end
end
