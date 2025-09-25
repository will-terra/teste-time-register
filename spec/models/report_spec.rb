# spec/models/report_spec.rb

require 'rails_helper'

RSpec.describe Report, type: :model do
  describe 'associations' do
    it { should belong_to(:user) }
  end

  describe 'validations' do
    subject { build(:report) }
    
    it { should validate_uniqueness_of(:process_id).ignoring_case_sensitivity }
    it { should validate_inclusion_of(:status).in_array(%w[queued processing completed failed]) }
    it { should validate_presence_of(:start_date) }
    it { should validate_presence_of(:end_date) }
    it { should validate_numericality_of(:progress).is_in(0..100) }

    # Testes customizados para campos com valores padrão
    it 'validates presence of process_id after creation' do
      report = Report.create(user: create(:user), start_date: 1.week.ago.to_date, end_date: Date.current)
      expect(report.process_id).to be_present
    end

    it 'validates presence of status after creation' do
      report = Report.create(user: create(:user), start_date: 1.week.ago.to_date, end_date: Date.current)
      expect(report.status).to be_present
    end

    it 'validates presence of progress after creation' do
      report = Report.create(user: create(:user), start_date: 1.week.ago.to_date, end_date: Date.current)
      expect(report.progress).to be_present
    end

    describe 'end_date_after_start_date validation' do
      it 'is valid when end_date is after start_date' do
        report = build(:report, start_date: 1.week.ago.to_date, end_date: Date.current)
        expect(report).to be_valid
      end

      it 'is invalid when end_date is before start_date' do
        report = build(:report, start_date: Date.current, end_date: 1.week.ago.to_date)
        expect(report).not_to be_valid
        expect(report.errors[:end_date]).to include('must be after start date')
      end

      it 'is valid when end_date equals start_date' do
        date = Date.current
        report = build(:report, start_date: date, end_date: date)
        expect(report).to be_valid
      end
    end
  end

  describe 'callbacks' do
    describe 'before_validation :set_defaults' do
      context 'on create' do
        it 'sets process_id if not present' do
          report = Report.new(user: create(:user), start_date: 1.week.ago.to_date, end_date: Date.current)
          expect(report.process_id).to be_nil
          
          report.valid?
          expect(report.process_id).to be_present
          expect(report.process_id).to match(/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\z/i)
        end

        it 'does not override existing process_id' do
          custom_uuid = SecureRandom.uuid
          report = Report.new(
            user: create(:user), 
            process_id: custom_uuid,
            start_date: 1.week.ago.to_date, 
            end_date: Date.current
          )
          
          report.valid?
          expect(report.process_id).to eq(custom_uuid)
        end

        it 'sets status to queued if not present' do
          report = Report.new(user: create(:user), start_date: 1.week.ago.to_date, end_date: Date.current)
          report.status = nil
          
          report.valid?
          expect(report.status).to eq('queued')
        end

        it 'sets progress to 0 if not present' do
          report = Report.new(user: create(:user), start_date: 1.week.ago.to_date, end_date: Date.current)
          report.progress = nil
          
          report.valid?
          expect(report.progress).to eq(0)
        end
      end
    end
  end

  describe 'scopes' do
    let!(:queued_report) { create(:report, status: 'queued') }
    let!(:processing_report) { create(:report, :processing) }
    let!(:completed_report) { create(:report, :completed) }
    let!(:failed_report) { create(:report, :failed) }

    describe '.by_status' do
      it 'returns reports with specified status' do
        expect(Report.by_status('queued')).to contain_exactly(queued_report)
        expect(Report.by_status('processing')).to contain_exactly(processing_report)
        expect(Report.by_status('completed')).to contain_exactly(completed_report)
        expect(Report.by_status('failed')).to contain_exactly(failed_report)
      end
    end
  end

  describe 'instance methods' do
    let(:report) { create(:report) }

    describe 'status check methods' do
      it '#queued? returns true for queued status' do
        report.update!(status: 'queued')
        expect(report.queued?).to be true
        expect(report.processing?).to be false
        expect(report.completed?).to be false
        expect(report.failed?).to be false
      end

      it '#processing? returns true for processing status' do
        report.update!(status: 'processing')
        expect(report.queued?).to be false
        expect(report.processing?).to be true
        expect(report.completed?).to be false
        expect(report.failed?).to be false
      end

      it '#completed? returns true for completed status' do
        report.update!(status: 'completed')
        expect(report.queued?).to be false
        expect(report.processing?).to be false
        expect(report.completed?).to be true
        expect(report.failed?).to be false
      end

      it '#failed? returns true for failed status' do
        report.update!(status: 'failed')
        expect(report.queued?).to be false
        expect(report.processing?).to be false
        expect(report.completed?).to be false
        expect(report.failed?).to be true
      end
    end

    describe '#file_exists?' do
      it 'returns false when file_path is nil' do
        report.update!(file_path: nil)
        expect(report.file_exists?).to be false
      end

      it 'returns false when file_path is present but file does not exist' do
        report.update!(file_path: '/non/existent/path.csv')
        expect(report.file_exists?).to be false
      end

      it 'returns true when file_path is present and file exists' do
        # Cria um arquivo temporário
        temp_file = Tempfile.new(['test_report', '.csv'])
        temp_file.write('test,data')
        temp_file.close
        
        report.update!(file_path: temp_file.path)
        expect(report.file_exists?).to be true
        
        # Limpa o arquivo temporário
        temp_file.unlink
      end
    end
  end

  describe 'dependent destroy' do
    let(:user) { create(:user) }
    let!(:reports) { create_list(:report, 3, user: user) }

    it 'destroys associated reports when user is destroyed' do
      report_ids = reports.map(&:id)
      
      expect { user.destroy! }.to change { Report.count }.by(-3)
      
      report_ids.each do |id|
        expect(Report.find_by(id: id)).to be_nil
      end
    end
  end
end