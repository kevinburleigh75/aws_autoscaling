class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  after_action :touch_healthcheck_file

  private

  def touch_healthcheck_file
    filename = Rails.root.join('tmp','status.txt').to_s
    FileUtils.touch(filename)
  end
end
