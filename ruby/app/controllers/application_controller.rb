class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  around_action :record_request

  def self.fake_aws_instance_id
    'some_fake_instance_id'
  end

  def self.fake_asg_name
    'some_fake_asg_name'
  end

  private

  def record_request
    start = Time.now

    yield

    elapsed = Time.now - start

    if Rails.env.production?
      aws_instance_id = ENV.fetch('AWS_INSTANCE_ID')
      aws_asg_name    = ENV.fetch('AWS_ASG_NAME')
      aws_lc_image_id = ENV.fetch('AWS_ASG_LC_IMAGE_ID')
    else
      aws_instance_id = ApplicationController.fake_aws_instance_id
      aws_asg_name    = ApplicationController.fake_asg_name
      aws_lc_image_id = 'some_fake_lc_image_id'
    end

    request_record = RequestRecord.new(
      request_record_uuid:    SecureRandom.uuid.to_s,
      request_fullpath:       request.fullpath,
      request_elapsed:        elapsed,
      aws_instance_id:        aws_instance_id,
      aws_asg_name:           aws_asg_name,
      aws_lc_image_id:        aws_lc_image_id,
      has_been_processed:     false,
    )

    request_record.save!
  end
end
