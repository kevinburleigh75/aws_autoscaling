class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  around_action :record_request

  after_action :touch_healthcheck_file

  private

  def touch_healthcheck_file
    filename = Rails.root.join('tmp','status.txt').to_s
    FileUtils.touch(filename)
  end

  def record_request
    start = Time.now

    yield

    elapsed = Time.now - start

    request_record = RequestRecord.new(
      instance_id:        ENV['AWS_INSTANCE_ID'],
      has_been_processed: false,
      elapsed:            elapsed,
      fullpath:           request.fullpath,
    )

    request_record.save!
  end
end
