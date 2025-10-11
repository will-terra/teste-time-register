# spec/factories/reports.rb

FactoryBot.define do
  # Default report factory with basic attributes for testing
  factory :report do
    association :user  # Links the report to a user
    process_id { SecureRandom.uuid }  # Unique identifier for the report process
    status { 'queued' }  # Initial status of the report
    progress { 0 }  # Progress percentage (0-100)
    start_date { 7.days.ago.to_date }  # Start date for the report period
    end_date { Date.current }  # End date for the report period
    file_path { nil }  # Path to the generated CSV file (nil if not generated)
    error_message { nil }  # Error message if report generation failed

    # Trait for reports in processing state
    trait :processing do
      status { 'processing' }
      progress { 50 }
    end

    # Trait for completed reports with a generated file
    trait :completed do
      status { 'completed' }
      progress { 100 }
      file_path { Rails.root.join('tmp', 'reports', "test_report_#{SecureRandom.hex(8)}.csv").to_s }
    end

    # Trait for failed reports with an error message
    trait :failed do
      status { 'failed' }
      progress { 0 }
      error_message { 'Something went wrong during report generation' }
    end

    # Trait that creates a sample CSV file after report creation
    trait :with_file do
      after(:create) do |report|
        # Creates a sample CSV file for testing
        FileUtils.mkdir_p(Rails.root.join('tmp', 'reports'))
        file_path = Rails.root.join('tmp', 'reports', "test_report_#{report.process_id}.csv")
        File.write(file_path, "Name,Email,Date\nTest User,test@example.com,#{Date.current}")
        report.update!(file_path: file_path.to_s, status: 'completed', progress: 100)
      end
    end

    # Trait for reports covering the current month
    trait :current_month do
      start_date { Date.current.beginning_of_month }
      end_date { Date.current.end_of_month }
    end

    # Trait for reports covering the last week
    trait :last_week do
      start_date { 1.week.ago.to_date }
      end_date { Date.current }
    end
  end
end
