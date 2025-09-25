# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

require 'faker'

puts "Iniciando população de dados..."

# Configurar locale do Faker para português brasileiro
Faker::Config.locale = 'pt-BR'

# Método para gerar usuários
def create_users(count = 100)
  puts "Criando #{count} usuários..."
  
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
        puts " Erro ao criar usuário (tentativa #{retries}): #{e.message}"
      end
    end
    
    print "." if (i + 1) % 10 == 0
  end
  
  puts "\n #{count} usuários criados com sucesso!"
  
  # Retorna todos os usuários (existentes + novos)
  User.all.limit(count)
end

# Método para gerar registros de ponto realistas
def create_time_registers_for_user(user, registers_count = 20)
  existing_registers = user.time_registers.count
  
  if existing_registers >= registers_count
    return
  end
  
  registers_to_create = registers_count - existing_registers
  
  # Gerar datas dos últimos 3 meses para simular histórico
  end_date = Date.current
  start_date = end_date - 3.months
  
  date_range = (start_date..end_date).to_a.select(&:on_weekday?)
  
  registers_to_create.times do |i|
    # Escolher uma data aleatória dos dias úteis
    work_date = date_range.sample
    
    # Simular horários comerciais com variações
    base_clock_in = work_date.beginning_of_day + 8.hours # 8:00
    base_clock_out = work_date.beginning_of_day + 18.hours # 18:00
    
    # Adicionar variações realistas (±30 minutos na entrada, ±1 hora na saída)
    clock_in_variation = rand(-30..30).minutes
    clock_out_variation = rand(-60..60).minutes
    
    clock_in = base_clock_in + clock_in_variation
    
    # Simular diferentes cenários
    case rand(1..100)
    when 1..5
      # 5% - Meio período (saída no almoço)
      clock_out = clock_in + 4.hours + rand(0..60).minutes
    when 6..10
      # 5% - Hora extra
      clock_out = base_clock_out + rand(1..3).hours + clock_out_variation
    when 11..15
      # 5% - Registros em aberto (esqueceu de bater saída)
      clock_out = nil
    else
      # 85% - Horário normal com intervalo de almoço
      clock_out = base_clock_out + clock_out_variation
    end
    
    # Evitar criar registros duplicados para a mesma data
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
      # Se der erro (ex: usuário já tem registro em aberto), tentar criar um registro completo
      if clock_out.nil?
        user.time_registers.create!(
          clock_in: clock_in,
          clock_out: clock_in + 8.hours + rand(-60..60).minutes
        )
      end
    end
  end
end

# Método para criar registros de ponto para todos os usuários
def create_time_registers(users, registers_per_user = 20)
  puts " Criando registros de ponto..."
  puts " #{registers_per_user} registros por usuário"
  
  users.each_with_index do |user, index|
    create_time_registers_for_user(user, registers_per_user)
    
    if (index + 1) % 10 == 0
      print "."
    end
  end
  
  puts "\n Registros de ponto criados!"
end

# Executar população de dados
begin
  # Limpar cache único do Faker para permitir re-execução
  Faker::UniqueGenerator.clear
  
  # Criar usuários
  users = create_users(100)
  
  # Criar registros de ponto
  create_time_registers(users, 20)
  
  puts "\n População de dados concluída com sucesso!"
  
rescue => e
  puts "\n Erro durante a população de dados:"
  puts "   #{e.message}"
  puts "   #{e.backtrace.first}"
end
