require "autotest"

module AutotestNotification

  VERSION = '2.4.0'

  Autotest.add_hook :ran_command do |autotest|
    lines = autotest.results.map { |s| s.gsub(/(\e.*?m|\n)/, '') }   # remove escape sequences
    result_line = lines.select { |line| line.match(/\d+\s+(example|test|scenario|step)s?/) }.last   # isolate result numbers

    report = Hash.new(0)
    %w{ tests assertions errors examples pendings failures }.map(&:to_sym).each do |x|
      report[x] = result_line[/(\d+) #{x}/, 1].to_i
    end

    if report[:tests] > 0
      code = 31 if report[:failures] > 0 || report[:errors] > 0
      msg  = unit_test_message(report[:tests], report[:assertions], report[:failures], report[:errors])
    elsif report[:examples]
      code = (report[:failures] > 0) ? 31 : (report[:pendings] > 0) ? 33 : 32
      msg  = rspec_message(report[:examples], report[:failures], report[:pendings])
    else
      code = 31
      msg  = "1 exception occurred"
      report[:failures] = 1
    end

    if report[:failures] > 0 || report[:errors] > 0
      notify "FAIL", msg, Config.fail_image, report[:tests] + report[:examples], report[:failures] + report[:errors], 2
    elsif PENDING && report[:pendings] > 0
      notify "Pending", msg, Config.pending_image, report[:tests] + report[:examples], report[:failures] + report[:errors], 1
    else
      notify "Pass", msg, Config.success_image, report[:tests] + report[:examples], 0, -2
    end

    puts "\e[#{code}m#{'=' * 80}\e[0m\n\n"
  end

  Autotest.add_hook :ran_features do |at|
    results = at.results.is_a?(Array) ? at.results : at.results.split("\n")
    if results
      # How many scenarios and steps have passed, are pending, have failed or are undefined?
      for result in results
        next unless result =~ /^\d+ (scenario|step)/
        scenario_or_step = $1
        %w( scenario step passed pending failed undefined ).each do |x|
          instance_variable_set "@#{scenario_or_step}_#{x}", result[/(\d+) #{x}/, 1].to_i
        end
      end

      count = @scenario_scenario + @step_step
      failed = @scenario_failed + @step_failed
      pending = @scenario_pending + @step_pending + @scenario_undefined + @step_undefined

      code = (failed > 0) ? 31 : (pending > 0) ? 33 : 32
      msg = feature_message(@scenario_scenario, @scenario_pending + @scenario_undefined, @scenario_failed, @step_step, @step_pending + @step_undefined, @step_failed)

      if @scenario_failed + @step_failed > 0
        notify "FAIL", msg, Config.fail_image, count, failed, 2
      elsif PENDING && pending > 0
        notify "Pending", msg, Config.pending_image, count, failed, 1
      else
        notify "Pass", msg, Config.success_image, count, 0, -2
      end
      puts "\e[#{code}m#{'=' * 80}\e[0m\n\n"
    end
  end

  class << self
    def notify(title, msg, img = Config.success_image, total = 1, failures = 0, priority = 0)

      img = Doom.image(total, failures) if DOOM_EDITION
      img = Buuf.image(title.downcase) if BUUF

      case RUBY_PLATFORM
      when /linux/
        Linux.notify(title, msg, img, total, failures, priority)
      when /darwin/
        Mac.notify(title, msg, img, total, failures, priority)
      when /cygwin/
        Cygwin.notify(title, msg, img, total, failures)
      when /mswin/
        Windows.notify(title, msg, img)
      end
    end

    def pluralize(text, number)
      "#{number} #{text}#{'s' if number != 1}"
    end

    def unit_test_message(tests, assertions, failures, errors)
      "#{pluralize('test', tests)}, #{pluralize('assertion', assertions)}, #{pluralize('failure', failures)}, #{pluralize('error', errors)}"
    end

    def rspec_message(examples, failures, pendings)
      "#{pluralize('example', examples)}, #{pluralize('failure', failures)}, #{pendings} pending"
    end

    def feature_message(scenarios, pending_scenarios, failed_scenarios, steps, pending_steps, failed_steps)
      "#{pluralize('scenario', scenarios)}, #{pluralize('failure', failed_scenarios)}, #{pending_scenarios} pending\n" +
      "#{pluralize('step', steps)}, #{pluralize('failure', failed_steps)}, #{pending_steps} pending"
    end
  end
end

%w{ linux mac windows cygwin doom buuf }.each { |x| require "autotest_notification/#{x}" }

if RUBY_PLATFORM == 'java'
  require 'java'
  AutotestNotification.const_set :RUBY_PLATFORM, java.lang.System.getProperty('os.name').downcase
end
