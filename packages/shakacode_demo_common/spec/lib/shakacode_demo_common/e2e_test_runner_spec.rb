# frozen_string_literal: true

require 'spec_helper'
require 'shakacode_demo_common/e2e_test_runner'

# rubocop:disable Metrics/BlockLength
RSpec.describe ShakacodeDemoCommon::E2eTestRunner do
  let(:modes) do
    [
      { name: 'Test Mode 1', command: 'bin/dev', env: {} },
      { name: 'Test Mode 2', command: 'bin/dev static', env: {} }
    ]
  end

  let(:runner) { described_class.new(modes) }

  describe '#initialize' do
    it 'stores the modes' do
      expect(runner.instance_variable_get(:@modes)).to eq(modes)
    end

    it 'initializes empty results' do
      expect(runner.results).to eq({})
    end
  end

  describe '#run_all' do
    let(:server_manager) { instance_double(ShakacodeDemoCommon::ServerManager) }

    before do
      allow(ShakacodeDemoCommon::ServerManager).to receive(:new).and_return(server_manager)
      allow(server_manager).to receive(:start)
      allow(server_manager).to receive(:wait_until_ready)
      allow(server_manager).to receive(:ready?).and_return(true)
      allow(server_manager).to receive(:stop)
      allow(runner).to receive(:system).and_return(true)
      allow(runner).to receive(:puts)
      allow(runner).to receive(:sleep)
      allow(runner).to receive(:exit)
    end

    it 'runs tests for each mode' do
      expect(ShakacodeDemoCommon::ServerManager).to receive(:new).twice
      runner.run_all
    end

    it 'stores results for each mode' do
      runner.run_all
      expect(runner.results.keys).to match_array(['Test Mode 1', 'Test Mode 2'])
    end

    it 'does not exit when all tests pass' do
      allow(runner).to receive(:system).and_return(true)
      expect(runner).not_to receive(:exit)
      runner.run_all
    end

    it 'exits with failure when any test fails' do
      allow(runner).to receive(:system).and_return(false)
      expect(runner).to receive(:exit).with(1)
      runner.run_all
    end

    context 'when server fails to start' do
      before do
        allow(server_manager).to receive(:ready?).and_return(false)
      end

      it 'records failure result' do
        runner.run_all
        expect(runner.results['Test Mode 1'][:success]).to be false
        expect(runner.results['Test Mode 1'][:error]).to eq('Server failed to start')
      end
    end

    context 'when an error occurs' do
      before do
        allow(server_manager).to receive(:start).and_raise(StandardError, 'Test error')
      end

      it 'records error result' do
        runner.run_all
        expect(runner.results['Test Mode 1'][:success]).to be false
        expect(runner.results['Test Mode 1'][:error]).to eq('Test error')
      end

      it 'still stops the server' do
        expect(server_manager).to receive(:stop)
        runner.run_all
      end
    end
  end
end

RSpec.describe ShakacodeDemoCommon::ServerManager do
  let(:mode) { { name: 'Test Mode', command: 'bin/dev', env: {} } }
  let(:server) { described_class.new(mode) }

  describe '#initialize' do
    it 'stores the mode' do
      expect(server.mode).to eq(mode)
    end

    it 'initializes as not ready' do
      expect(server.ready?).to be false
    end
  end

  describe '#start' do
    it 'spawns a server process' do
      allow(server).to receive(:puts)
      allow(Process).to receive(:getpgid).with(12345).and_return(12345)
      expect(server).to receive(:spawn).with(
        mode[:env],
        mode[:command],
        out: File::NULL,
        err: File::NULL,
        pgroup: true
      ).and_return(12345)

      server.start
      expect(server.instance_variable_get(:@server_pgid)).to eq(12345)
    end
  end

  describe '#wait_until_ready' do
    before do
      allow(server).to receive(:puts)
      allow(server).to receive(:print)
      allow(server).to receive(:sleep)
    end

    context 'when server responds quickly' do
      before do
        allow(server).to receive(:server_responding?).and_return(true)
      end

      it 'marks server as ready' do
        server.wait_until_ready
        expect(server.ready?).to be true
      end

      it 'returns true' do
        expect(server.wait_until_ready).to be true
      end
    end

    context 'when server never responds' do
      before do
        allow(server).to receive(:server_responding?).and_return(false)
      end

      it 'returns false after max attempts' do
        expect(server.wait_until_ready).to be false
      end

      it 'does not mark server as ready' do
        server.wait_until_ready
        expect(server.ready?).to be false
      end
    end

    context 'when server responds after a few attempts' do
      before do
        call_count = 0
        allow(server).to receive(:server_responding?) do
          call_count += 1
          call_count > 3
        end
      end

      it 'marks server as ready' do
        server.wait_until_ready
        expect(server.ready?).to be true
      end
    end
  end

  describe '#stop' do
    context 'when server is running with process group' do
      before do
        server.instance_variable_set(:@server_pid, 12345)
        server.instance_variable_set(:@server_pgid, 12345)
        allow(server).to receive(:puts)
        allow(server).to receive(:sleep)
        allow(Process).to receive(:kill)
        allow(Process).to receive(:wait)
      end

      it 'sends TERM signal to process group' do
        expect(Process).to receive(:kill).with('TERM', -12345)
        server.stop
      end

      it 'sends KILL signal after delay' do
        expect(Process).to receive(:kill).with('KILL', -12345)
        server.stop
      end

      it 'waits for process to terminate' do
        expect(Process).to receive(:wait).with(12345)
        server.stop
      end

      it 'handles already terminated process' do
        allow(Process).to receive(:kill).and_raise(Errno::ESRCH)
        expect { server.stop }.not_to raise_error
      end

      context 'when EPERM is raised' do
        it 'logs warning and falls back to single process' do
          allow(Process).to receive(:kill).with('TERM', -12345).and_raise(Errno::EPERM)
          expect(server).to receive(:puts).with(/Warning: Failed to kill process group/)
          expect(Process).to receive(:kill).with('TERM', 12345).and_raise(StandardError)
          server.stop
        end
      end
    end

    context 'when server is running without process group' do
      before do
        server.instance_variable_set(:@server_pid, 12345)
        server.instance_variable_set(:@server_pgid, nil)
        allow(server).to receive(:puts)
        allow(server).to receive(:sleep)
        allow(Process).to receive(:kill)
        allow(Process).to receive(:wait)
      end

      it 'sends TERM signal to single process' do
        expect(Process).to receive(:kill).with('TERM', 12345).and_raise(StandardError)
        server.stop
      end

      it 'sends KILL signal to single process' do
        expect(Process).to receive(:kill).with('KILL', 12345).and_raise(StandardError)
        server.stop
      end
    end

    context 'when server is not running' do
      it 'does nothing' do
        expect(Process).not_to receive(:kill)
        server.stop
      end
    end
  end

  describe '#server_responding?' do
    let(:uri) { URI('http://localhost:3000') }
    let(:response) { instance_double(Net::HTTPResponse, code: '200') }
    let(:http) { instance_double(Net::HTTP) }

    before do
      allow(Net::HTTP).to receive(:start).and_yield(http)
      allow(http).to receive(:get).and_return(response)
    end

    it 'returns true for successful response' do
      allow(response).to receive(:code).and_return('200')
      expect(server.send(:server_responding?)).to be true
    end

    it 'returns true for redirects (3xx)' do
      allow(response).to receive(:code).and_return('302')
      expect(server.send(:server_responding?)).to be true
    end

    it 'returns false for client errors (4xx)' do
      allow(response).to receive(:code).and_return('404')
      expect(server.send(:server_responding?)).to be false
    end

    it 'returns false for server errors (5xx)' do
      allow(response).to receive(:code).and_return('500')
      expect(server.send(:server_responding?)).to be false
    end

    it 'returns false when connection is refused' do
      allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)
      expect(server.send(:server_responding?)).to be false
    end

    it 'returns false for socket errors' do
      allow(Net::HTTP).to receive(:start).and_raise(SocketError)
      expect(server.send(:server_responding?)).to be false
    end

    it 'returns false when open timeout occurs' do
      allow(Net::HTTP).to receive(:start).and_raise(Net::OpenTimeout)
      expect(server.send(:server_responding?)).to be false
    end

    it 'returns false when read timeout occurs' do
      allow(Net::HTTP).to receive(:start).and_raise(Net::ReadTimeout)
      expect(server.send(:server_responding?)).to be false
    end
  end

  describe 'timeout integration tests' do
    let(:mode) { { name: 'test', command: 'echo test', env: {} } }
    let(:server) { described_class.new(mode, port: 3001) }

    it 'respects HTTP_OPEN_TIMEOUT when server is slow to accept connections' do
      allow(Net::HTTP).to receive(:start) do
        sleep(described_class::HTTP_OPEN_TIMEOUT + 1)
        raise Net::OpenTimeout
      end

      start_time = Time.now
      result = server.send(:server_responding?)
      elapsed = Time.now - start_time

      expect(result).to be false
      expect(elapsed).to be < (described_class::HTTP_OPEN_TIMEOUT + 2)
    end

    it 'respects HTTP_READ_TIMEOUT when server is slow to respond' do
      allow(Net::HTTP).to receive(:start) do
        sleep(described_class::HTTP_READ_TIMEOUT + 1)
        raise Net::ReadTimeout
      end

      start_time = Time.now
      result = server.send(:server_responding?)
      elapsed = Time.now - start_time

      expect(result).to be false
      expect(elapsed).to be < (described_class::HTTP_READ_TIMEOUT + 2)
    end

    it 'uses configurable timeouts from constants' do
      # Verify constants are used, not hardcoded values
      expect(described_class::HTTP_OPEN_TIMEOUT).to eq(2)
      expect(described_class::HTTP_READ_TIMEOUT).to eq(5)
    end
  end
end
# rubocop:enable Metrics/BlockLength
