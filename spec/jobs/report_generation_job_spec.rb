# spec/jobs/report_generation_job_spec.rb

require 'rails_helper'

RSpec.describe ReportGenerationJob, type: :job do
  include ActiveJob::TestHelper

  let(:user) { create(:user) }
  let(:report) { create(:report, user: user, start_date: 7.days.ago.to_date, end_date: Date.current) }

  before do
    # Cleans test directory before each test
    FileUtils.rm_rf(Rails.root.join('tmp', 'reports'))
  end

  after do
    # Cleans files created during tests after each test
    FileUtils.rm_rf(Rails.root.join('tmp', 'reports'))
  end

  describe '#perform' do
    context 'when report exists and user has time registers' do
      let!(:time_registers) do
        [
          create(:time_register,
                 user: user,
                 clock_in: 2.days.ago.beginning_of_day + 8.hours,
                 clock_out: 2.days.ago.beginning_of_day + 17.hours),
          create(:time_register,
                 user: user,
                 clock_in: 1.day.ago.beginning_of_day + 9.hours,
                 clock_out: 1.day.ago.beginning_of_day + 18.hours)
        ]
      end

      it 'generates CSV file successfully' do
        expect {
          perform_enqueued_jobs { described_class.perform_later(report.id) }
        }.to change { report.reload.status }.from('queued').to('completed')
          .and change { report.reload.progress }.from(0).to(100)
      end

      it 'creates the CSV file in the correct location' do
        perform_enqueued_jobs { described_class.perform_later(report.id) }

        report.reload
        expect(report.file_path).to be_present
        expect(File.exist?(report.file_path)).to be true
      end

      it 'generates CSV with correct content structure' do
        perform_enqueued_jobs { described_class.perform_later(report.id) }

        report.reload
        csv_content = File.read(report.file_path)

        expect(csv_content).to include('Nome do Usuário,Email,Data,Entrada,Saída,Horas Trabalhadas,Status')
        expect(csv_content).to include(user.name)
        expect(csv_content).to include(user.email)
        expect(csv_content).to include('Total:')
      end

      it 'calculates worked hours correctly' do
        perform_enqueued_jobs { described_class.perform_later(report.id) }

        report.reload
        csv_content = File.read(report.file_path)

        expect(csv_content).to include('9h 0m') # First register: 17h - 8h = 9h
        expect(csv_content).to include('Total: 18h 0m') # Total: 9h + 9h = 18h
      end

      it 'updates progress during execution' do
        perform_enqueued_jobs { described_class.perform_later(report.id) }

        # Verifies that progress was updated correctly
        report.reload
        expect(report.status).to eq('completed')
        expect(report.progress).to eq(100)
      end
    end

    context 'when user has no time registers in the period' do
      it 'generates empty CSV successfully' do
        perform_enqueued_jobs { described_class.perform_later(report.id) }

        report.reload
        expect(report.status).to eq('completed')
        expect(report.progress).to eq(100)

        csv_content = File.read(report.file_path)
        lines = csv_content.split("\n")
        expect(lines.length).to eq(1) # Only the header
        expect(lines.first).to include('Nome do Usuário,Email,Data,Entrada,Saída,Horas Trabalhadas,Status')
      end
    end

    context 'when user has open time registers' do
      let!(:open_register) do
        create(:time_register, :open,
               user: user,
               clock_in: 1.day.ago.beginning_of_day + 8.hours)
      end

      it 'handles open registers correctly' do
        perform_enqueued_jobs { described_class.perform_later(report.id) }

        report.reload
        csv_content = File.read(report.file_path)

        expect(csv_content).to include('Em andamento')
        expect(csv_content).to include('0h 0m') # No worked hours for open register
      end
    end

    context 'when report does not exist' do
      it 'raises ActiveRecord::RecordNotFound' do
        expect {
          described_class.new.perform(99999)
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    context 'when an error occurs during generation' do
      before do
        # Simulates an error during generation
        allow(File).to receive(:write).and_raise(StandardError.new('Disk full'))
      end

      it 'updates report status to failed' do
        expect {
          described_class.new.perform(report.id)
        }.to raise_error(StandardError, 'Disk full')

        report.reload
        expect(report.status).to eq('failed')
        expect(report.error_message).to eq('Disk full')
        expect(report.progress).to eq(0)
      end

      it 'logs the error' do
        expect(Rails.logger).to receive(:error).with(/Report generation failed for report #{report.id}/)
        expect(Rails.logger).to receive(:error).with(anything) # backtrace

        expect {
          described_class.new.perform(report.id)
        }.to raise_error(StandardError)
      end
    end
  end

  describe 'job configuration' do
    it 'is queued in the reports queue' do
      described_class.perform_later(report.id)
      expect(enqueued_jobs.last[:queue]).to eq('reports')
    end
  end

  describe 'private methods' do
    let(:job) { described_class.new }
    let!(:time_registers) do
      [
        create(:time_register,
               user: user,
               clock_in: 1.day.ago.beginning_of_day + 8.hours,
               clock_out: 1.day.ago.beginning_of_day + 17.hours),
        create(:time_register, :open,
               user: user,
               clock_in: Time.current.beginning_of_day + 9.hours)
      ]
    end

    describe '#fetch_time_registers' do
      it 'returns time registers within date range' do
        registers = job.send(:fetch_time_registers, user, 7.days.ago.to_date, Date.current)
        expect(registers).to include(*time_registers)
      end

      it 'orders registers by clock_in' do
        registers = job.send(:fetch_time_registers, user, 7.days.ago.to_date, Date.current)
        expect(registers.to_sql).to include('ORDER BY "time_registers"."clock_in"')
      end

      it 'includes user association' do
        registers = job.send(:fetch_time_registers, user, 7.days.ago.to_date, Date.current)
        # Verifies that the user was included in the query
        expect(registers.first.association(:user).loaded?).to be true
      end
    end

    describe '#calculate_worked_hours' do
      it 'returns formatted hours for completed register' do
        register = time_registers.first # closed register
        result = job.send(:calculate_worked_hours, register)
        expect(result).to eq('9h 0m')
      end

      it 'returns 0h 0m for open register' do
        register = time_registers.last # open register
        result = job.send(:calculate_worked_hours, register)
        expect(result).to eq('0h 0m')
      end
    end

    describe '#calculate_total_hours' do
      it 'calculates total hours for completed registers' do
        result = job.send(:calculate_total_hours, time_registers)
        expect(result).to eq('9h 0m') # Only the first register has clock_out
      end
    end
  end
end
