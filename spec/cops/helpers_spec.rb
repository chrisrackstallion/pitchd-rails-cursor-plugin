# frozen_string_literal: true

require "spec_helper"
require "cops/cop_helper"

RSpec.describe RuboCop::Cop::AgentHarnessRails::HelperModuleLength, :config do
  let(:cop_config) { { "Max" => 3, "CountComments" => false, "CountAsOne" => [] } }

  it "flags a domain helper past the limit" do
    expect_offense(<<~RUBY)
      module BillingHelper
      ^^^^^^^^^^^^^^^^^^^^ `BillingHelper` has too many lines. [4/3] Move the cohesive cluster into a subdomain helper under app/helpers/<domain>/.
        def invoice_total(invoice); number_to_currency(invoice.total); end
        def invoice_due(invoice); l(invoice.due_on); end
        def plan_name(plan); plan.name.titleize; end
        def plan_price(plan); number_to_currency(plan.price); end
      end
    RUBY
  end

  it "measures a subdomain helper without its namespace wrapper" do
    expect_no_offenses(<<~RUBY)
      module Billing
        # Wrapper lines do not count against the helper inside.
        module InvoicesHelper
          def invoice_total(invoice); number_to_currency(invoice.total); end
          def invoice_due(invoice); l(invoice.due_on); end
        end
      end
    RUBY
  end
end
