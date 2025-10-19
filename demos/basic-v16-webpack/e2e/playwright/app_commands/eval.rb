# frozen_string_literal: true

# rubocop:disable Security/Eval
Kernel.eval(command_options) unless command_options.nil?
# rubocop:enable Security/Eval
