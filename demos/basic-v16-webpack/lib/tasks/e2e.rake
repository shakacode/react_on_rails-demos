# frozen_string_literal: true

require_relative '../../../shakacode_demo_common/e2e_test_runner'

namespace :e2e do
  desc 'Run Playwright tests against all dev modes (bin/dev, bin/dev static, bin/dev prod)'
  task :test_all_modes do
    modes = [
      { name: 'Development (bin/dev)', command: 'bin/dev', env: {} },
      { name: 'Development Static (bin/dev static)', command: 'bin/dev static', env: {} },
      { name: 'Development Production (bin/dev prod)', command: 'bin/dev prod', env: {} }
    ]

    runner = ShakacodeDemoCommon::E2eTestRunner.new(modes)
    runner.run_all
  end

  desc 'Run Playwright tests (assumes server is already running)'
  task test: :environment do
    exec 'bin/rails playwright:run'
  end

  desc 'Open Playwright test UI'
  task open: :environment do
    exec 'bin/rails playwright:open'
  end

  desc 'Show Playwright test report'
  task report: :environment do
    exec 'npx playwright show-report'
  end
end
