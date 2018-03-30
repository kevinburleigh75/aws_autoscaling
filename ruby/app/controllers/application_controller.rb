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

    aws_asg_name = %r{^.*?-(?<asg_name>.*?)Stack-}.match(ENV['AWS_ASG_NAME'])['asg_name']

    request_record = RequestRecord.new(
      request_uuid:           SecureRandom.uuid.to_s,
      request_fullpath:       request.fullpath,
      request_elapsed:        elapsed,
      aws_instance_id:        ENV['AWS_INSTANCE_ID'],
      aws_asg_name:           aws_asg_name,
      aws_lc_image_id:        ENV['AWS_ASG_LC_IMAGE_ID'],
      has_been_processed:     false,
    )

    request_record.save!
  end
end
