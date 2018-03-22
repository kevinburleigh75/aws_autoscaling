class PingsController < ApplicationController
  def ping
    render plain: "I'm so alive"
  end
end