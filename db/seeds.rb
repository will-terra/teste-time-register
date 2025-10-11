# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require 'faker'

puts "Starting data population..."

# Configure Faker locale to Brazilian Portuguese
Faker::Config.locale = 'pt-BR'

# Method to generate users
def create_users(count = 100)
  puts "Creating #{count} users..."

  users = []
  count.times do |i|
    user = nil
    retries = 0

    while user.nil? && retries < 10
      begin
        user = User.create!(
          name: Faker::Name.name,
          email: Faker::Internet.unique.email
        )
        users << user
      rescue ActiveRecord::RecordInvalid => e
        retries += 1
        puts " Error creating user (attempt #{retries}): #{e.message}"
      end
    end

    print "." if (i + 1) % 10 == 0
  end

  puts "\n #{count} users created successfully!"

  # Returns all users (existing + new)
  User.all.limit(count)
end

# Method to generate realistic time register entries
def create_time_registers_for_user(user, registers_count = 20)
  existing_registers = user.time_registers.count

  if existing_registers >= registers_count
    return
  end

  registers_to_create = registers_count - existing_registers

  # Generate dates from the last 3 months to simulate history
  end_date = Date.current
  start_date = end_date - 3.months

  date_range = (start_date..end_date).to_a.select(&:on_weekday?)

  registers_to_create.times do |i|
    # Choose a random date from weekdays
    work_date = date_range.sample

    # Simulate business hours with variations
    base_clock_in = work_date.beginning_of_day + 8.hours # 8:00
    base_clock_out = work_date.beginning_of_day + 18.hours # 18:00

    # Add realistic variations (±30 minutes on entry, ±1 hour on exit)
    clock_in_variation = rand(-30..30).minutes
    clock_out_variation = rand(-60..60).minutes

    clock_in = base_clock_in + clock_in_variation

    # Simulate different scenarios
    case rand(1..100)
    when 1..5
      # 5% - Half period (left at lunch)
      clock_out = clock_in + 4.hours + rand(0..60).minutes
    when 6..10
      # 5% - Overtime
      clock_out = base_clock_out + rand(1..3).hours + clock_out_variation
    when 11..15
      # 5% - Open records (forgot to clock out)
      clock_out = nil
    else
      # 85% - Normal hours with lunch break
      clock_out = base_clock_out + clock_out_variation
    end

    # Avoid creating duplicate records for the same date
    existing_register = user.time_registers.where(
      "DATE(clock_in) = ?", work_date
    ).first

    next if existing_register

    begin
      user.time_registers.create!(
        clock_in: clock_in,
        clock_out: clock_out
      )
    rescue ActiveRecord::RecordInvalid
      # If there's an error (e.g., user already has an open record), try to create a complete record
      if clock_out.nil?
        user.time_registers.create!(
          clock_in: clock_in,
          clock_out: clock_in + 8.hours + rand(-60..60).minutes
        )
      end
    end
  end
end

# Method to create time register entries for all users
def create_time_registers(users, registers_per_user = 20)
  puts " Creating time register entries..."
  puts " #{registers_per_user} registers per user"

  users.each_with_index do |user, index|
    create_time_registers_for_user(user, registers_per_user)

    if (index + 1) % 10 == 0
      print "."
    end
  end

  puts "\n Time register entries created!"
end

# Execute data population
begin
  # Clear Faker's unique cache to allow re-execution
  Faker::UniqueGenerator.clear

  # Create users
  users = create_users(100)

  # Create time register entries
  create_time_registers(users, 20)

  puts "\n Data population completed successfully!"

rescue => e
  puts "\n Error during data population:"
  puts "   #{e.message}"
  puts "   #{e.backtrace.first}"
end
