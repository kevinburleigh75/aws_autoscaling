class PingsController < ApplicationController
  def ping
    render plain: "I'm so alive"

    filename = Rails.root.join('tmp','status.txt').to_s
    FileUtils.touch(filename)
  end
end