class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  after_action :touch_healthcheck_file
  after_action :record_request_handled

  private

  def touch_healthcheck_file
    filename = Rails.root.join('tmp','status.txt').to_s
    FileUtils.touch(filename)
  end

  def record_request
    record = RequestRecord.new(
      instance_id:        ENV['AWS_INSTANCE_ID'],
      has_been_processed: false,
    )
    record.save!
  end
end
