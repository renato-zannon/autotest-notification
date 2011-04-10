module AutotestNotification
  class Config
    class << self
      attr_reader :images_directory
      attr_accessor :success_image, :fail_image, :pending_image, :expiration_in_seconds

      def images_directory=(path)
        @images_directory = File.expand_path(path)

        @success_image = "#{@images_directory}/pass.png"
        @fail_image    = "#{@images_directory}/fail.png"
        @pending_image = "#{@images_directory}/pending.png"
      end
    end

    self.images_directory = "#{File.dirname(__FILE__)}/../images/"
    self.expiration_in_seconds = 3
  end
end
