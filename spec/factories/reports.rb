# spec/factories/reports.rb

FactoryBot.define do
  factory :report do
    association :user
    process_id { SecureRandom.uuid }
    status { 'queued' }
    progress { 0 }
    start_date { 7.days.ago.to_date }
    end_date { Date.current }
    file_path { nil }
    error_message { nil }

    trait :processing do
      status { 'processing' }
      progress { 50 }
    end

    trait :completed do
      status { 'completed' }
      progress { 100 }
      file_path { Rails.root.join('tmp', 'reports', "test_report_#{SecureRandom.hex(8)}.csv").to_s }
    end

    trait :failed do
      status { 'failed' }
      progress { 0 }
      error_message { 'Something went wrong during report generation' }
    end

    trait :with_file do
      after(:create) do |report|
        # Cria um arquivo CSV de exemplo
        FileUtils.mkdir_p(Rails.root.join('tmp', 'reports'))
        file_path = Rails.root.join('tmp', 'reports', "test_report_#{report.process_id}.csv")
        File.write(file_path, "Name,Email,Date\nTest User,test@example.com,#{Date.current}")
        report.update!(file_path: file_path.to_s, status: 'completed', progress: 100)
      end
    end

    trait :current_month do
      start_date { Date.current.beginning_of_month }
      end_date { Date.current.end_of_month }
    end

    trait :last_week do
      start_date { 1.week.ago.to_date }
      end_date { Date.current }
    end
  end
end